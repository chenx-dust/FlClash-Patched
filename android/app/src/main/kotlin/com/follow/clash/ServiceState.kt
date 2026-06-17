package com.follow.clash

import android.net.VpnService
import com.follow.clash.common.GlobalState
import com.follow.clash.models.SharedState
import com.follow.clash.plugins.AppPlugin
import com.follow.clash.plugins.TilePlugin
import com.follow.clash.service.ServiceConfig
import com.follow.clash.service.models.NotificationParams
import com.follow.clash.service.models.VpnOptions
import com.google.gson.Gson
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

enum class RunState {
    STARTED,
    STARTING,
    STOPPING,
    STOPPED,
}

object ServiceState {
    private val lock = Mutex()
    private val mutableRunState = MutableStateFlow(RunState.STOPPED)
    @Volatile
    private var sharedState = SharedState()
    @Volatile
    private var flutterEngine: FlutterEngine? = null

    val runState = mutableRunState.asStateFlow()

    var runTimeMillis = 0L
        private set

    private val appPlugin: AppPlugin?
        get() = flutterEngine?.plugin<AppPlugin>()

    private val tilePlugin: TilePlugin?
        get() = flutterEngine?.plugin<TilePlugin>()

    fun attachFlutterEngine(engine: FlutterEngine) {
        flutterEngine = engine
    }

    fun detachFlutterEngine(engine: FlutterEngine) {
        if (flutterEngine === engine) {
            flutterEngine = null
        }
    }

    suspend fun handleToggleAction() {
        when (runState.value) {
            RunState.STARTED -> handleStopAction()
            RunState.STOPPED -> handleStartAction()
            RunState.STARTING, RunState.STOPPING -> Unit
        }
    }

    suspend fun refresh() = lock.withLock {
        if (runState.value == RunState.STARTING || runState.value == RunState.STOPPING) {
            return@withLock
        }
        runTimeMillis = ServiceController.getRunTimeMillis()
        mutableRunState.value = if (runTimeMillis == 0L) RunState.STOPPED else RunState.STARTED
    }

    suspend fun handleStartAction() {
        val shouldStartInBackground = lock.withLock {
            if (runState.value != RunState.STOPPED) {
                return@withLock false
            }
            tilePlugin?.handleStart()
            flutterEngine == null
        }
        if (shouldStartInBackground) {
            loadPreferencesAndStart()
        }
    }

    suspend fun handleStopAction() {
        val shouldStopInBackground = lock.withLock {
            if (runState.value != RunState.STARTED) {
                return@withLock false
            }
            tilePlugin?.handleStop()
            flutterEngine == null
        }
        if (shouldStopInBackground) {
            GlobalState.application.showToast(
                GlobalState.application.getString(R.string.stop_vpn),
            )
            launchStop()
        }
    }

    fun requestStart() {
        val plugin = appPlugin
        if (plugin == null) {
            launchStart()
            return
        }
        plugin.requestNotificationPermission(::launchStart)
    }

    fun requestStop() {
        launchStop()
    }

    fun syncSharedState(state: SharedState) {
        sharedState = state
        applySharedState()
    }

    fun handleServiceDisconnected() {
        GlobalState.launch {
            lock.withLock {
                runTimeMillis = 0L
                mutableRunState.value = RunState.STOPPED
            }
        }
    }

    private fun loadPreferencesAndStart() {
        GlobalState.launch {
            sharedState = GlobalState.application.sharedState
            setupAndStart()
        }
    }

    private fun applySharedState() {
        ServiceConfig.updateNotificationParams(
            NotificationParams(
                title = sharedState.currentProfileName,
                onlyStatisticsProxy = sharedState.onlyStatisticsProxy,
                networkSpeedNotification = sharedState.networkSpeedNotification,
            ),
        )
    }

    private fun setupAndStart() {
        applySharedState()
        GlobalState.application.showToast(
            GlobalState.application.getString(R.string.start_vpn),
        )
        val initParams = Gson().toJson(
            mapOf(
                "home-dir" to GlobalState.application.filesDir.path,
                "version" to android.os.Build.VERSION.SDK_INT,
            ),
        )
        val setupParams = Gson().toJson(sharedState.setupParams)
        ServiceController.quickSetup(
            initParams,
            setupParams,
            onStarted = ::launchStart,
            onResult = { message ->
                if (message.isNotEmpty()) {
                    GlobalState.application.showToast(message)
                }
            },
        ).onFailure { error ->
            GlobalState.log("Unable to set up core: $error")
        }
    }

    private fun launchStart() {
        GlobalState.launch {
            val options = lock.withLock {
                if (runState.value != RunState.STOPPED) {
                    return@launch
                }
                val value = sharedState.vpnOptions ?: return@launch
                mutableRunState.value = RunState.STARTING
                value
            }

            val plugin = appPlugin
            if (plugin != null) {
                plugin.prepareVpn(options.enable) { granted ->
                    if (granted) {
                        completeStart(options)
                    } else {
                        cancelStart()
                    }
                }
                return@launch
            }

            if (options.enable && VpnService.prepare(GlobalState.application) != null) {
                cancelStart()
                return@launch
            }
            completeStart(options)
        }
    }

    private fun completeStart(options: VpnOptions) {
        GlobalState.launch {
            lock.withLock {
                if (runState.value != RunState.STARTING) {
                    return@withLock
                }
                runTimeMillis = ServiceController.start(options, runTimeMillis)
                mutableRunState.value =
                    if (runTimeMillis == 0L) RunState.STOPPED else RunState.STARTED
            }
        }
    }

    private fun cancelStart() {
        GlobalState.launch {
            lock.withLock {
                if (runState.value == RunState.STARTING) {
                    mutableRunState.value = RunState.STOPPED
                }
            }
        }
    }

    private fun launchStop() {
        GlobalState.launch {
            lock.withLock {
                if (runState.value != RunState.STARTED) {
                    return@withLock
                }
                mutableRunState.value = RunState.STOPPING
                runTimeMillis = ServiceController.stop()
                mutableRunState.value = RunState.STOPPED
            }
        }
    }
}

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

private const val MISSING_CONFIG_MESSAGE = "No configuration found."
private const val INVALID_CONFIG_MESSAGE = "Invalid configuration."
private const val VPN_PERMISSION_MESSAGE = "VPN permission required."
private const val START_FAILED_MESSAGE = "Failed to start service."

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
            GlobalState.application.showToast(sharedState.stopTip)
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

    private suspend fun loadPreferencesAndStart() {
        sharedState = GlobalState.application.sharedState
        if (sharedState.setupParams == null || sharedState.vpnOptions == null) {
            GlobalState.application.showToast(MISSING_CONFIG_MESSAGE)
            return
        }
        if (setupCore()) {
            startInBackground()
        }
    }

    private fun applySharedState() {
        GlobalState.setCrashlytics(sharedState.crashlytics)
        ServiceConfig.updateNotificationParams(
            NotificationParams(
                title = sharedState.currentProfileName,
                stopText = sharedState.stopText,
                onlyStatisticsProxy = sharedState.onlyStatisticsProxy,
            ),
        )
    }

    private suspend fun setupCore(): Boolean {
        applySharedState()
        GlobalState.application.showToast(sharedState.startTip)
        val initParams = Gson().toJson(
            mapOf(
                "home-dir" to GlobalState.application.filesDir.path,
                "version" to android.os.Build.VERSION.SDK_INT,
            ),
        )
        val setupParams = Gson().toJson(sharedState.setupParams)
        return ServiceController.quickSetup(
            initParams,
            setupParams,
        ).fold(
            onSuccess = { message ->
                if (message.isEmpty()) {
                    true
                } else {
                    GlobalState.log("Unable to set up core: $message")
                    showConfigError(message)
                    false
                }
            },
            onFailure = { error ->
                GlobalState.log("Unable to set up core: $error")
                showConfigError(error.message)
                false
            },
        )
    }

    private fun showConfigError(message: String?) {
        GlobalState.application.showToast(
            message?.takeIf { it.isNotBlank() } ?: INVALID_CONFIG_MESSAGE,
        )
    }

    private fun launchStart() {
        GlobalState.launch {
            val options = beginStart() ?: return@launch

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
                cancelStartNow()
                return@launch
            }
            completeStartNow(options)
        }
    }

    private suspend fun startInBackground() {
        val options = beginStart() ?: return
        if (options.enable && VpnService.prepare(GlobalState.application) != null) {
            cancelStartNow()
            GlobalState.application.showToast(VPN_PERMISSION_MESSAGE)
            return
        }
        if (!completeStartNow(options)) {
            GlobalState.application.showToast(START_FAILED_MESSAGE)
        }
    }

    private suspend fun beginStart(): VpnOptions? = lock.withLock {
        if (runState.value != RunState.STOPPED) {
            return@withLock null
        }
        val value = sharedState.vpnOptions ?: return@withLock null
        mutableRunState.value = RunState.STARTING
        value
    }

    private fun completeStart(options: VpnOptions) {
        GlobalState.launch {
            completeStartNow(options)
        }
    }

    private suspend fun completeStartNow(options: VpnOptions): Boolean = lock.withLock {
        if (runState.value != RunState.STARTING) {
            return@withLock false
        }
        runTimeMillis = ServiceController.start(options, runTimeMillis)
        mutableRunState.value =
            if (runTimeMillis == 0L) RunState.STOPPED else RunState.STARTED
        runTimeMillis != 0L
    }

    private fun cancelStart() {
        GlobalState.launch {
            cancelStartNow()
        }
    }

    private suspend fun cancelStartNow() = lock.withLock {
        if (runState.value == RunState.STARTING) {
            mutableRunState.value = RunState.STOPPED
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

package com.follow.clash.service.modules

import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import androidx.core.content.getSystemService
import com.follow.clash.common.receiveBroadcastFlow
import com.follow.clash.core.Core
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.launch

internal class SuspendModule(
    private val service: Service,
    private val scope: CoroutineScope,
) : ServiceModule {
    private var isSuspended = false

    private val powerManager: PowerManager? by lazy {
        service.getSystemService<PowerManager>()
    }

    private fun isScreenOn(): Boolean = powerManager?.isInteractive ?: true

    private val isDeviceIdleMode: Boolean
        get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            powerManager?.isDeviceIdleMode == true

    private val shouldSuspend: Boolean
        get() = !isScreenOn() && isDeviceIdleMode

    private fun updateSuspendState() {
        val shouldSuspendNow = shouldSuspend
        when {
            shouldSuspendNow && !isSuspended -> {
                Core.suspended(true)
                isSuspended = true
            }

            !shouldSuspendNow && isSuspended -> resumeIfSuspended()
        }
    }

    private fun resumeIfSuspended() {
        if (!isSuspended) return
        Core.suspended(false)
        isSuspended = false
    }

    override fun start() {
        isSuspended = false
        scope.launch {
            val screenFlow = service.receiveBroadcastFlow {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    addAction(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED)
                }
            }.map {
                it.action
            }.onStart {
                emit(null)
            }

            screenFlow.collect { action ->
                if (action == Intent.ACTION_SCREEN_ON) {
                    resumeIfSuspended()
                } else {
                    updateSuspendState()
                }
            }
        }
    }

    override fun stop() {
        resumeIfSuspended()
    }
}

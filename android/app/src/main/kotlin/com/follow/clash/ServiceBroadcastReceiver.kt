package com.follow.clash

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.follow.clash.common.BroadcastAction
import com.follow.clash.common.GlobalState
import com.follow.clash.common.action
import kotlinx.coroutines.launch

class ServiceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val action = intent?.action ?: return
        val pendingResult = goAsync()
        GlobalState.launch {
            try {
                handleAction(action)
            } finally {
                pendingResult.finish()
            }
        }
    }

    private suspend fun handleAction(action: String) {
        when (action) {
            BroadcastAction.SERVICE_CREATED.action -> {
                GlobalState.log("Background service created")
                ServiceState.handleStartAction()
            }

            BroadcastAction.SERVICE_DESTROYED.action -> {
                GlobalState.log("Background service destroyed")
                ServiceState.handleStopAction()
            }
        }
    }
}

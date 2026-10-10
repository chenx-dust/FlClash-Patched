package cc.chenx.flclash

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import androidx.core.content.pm.ShortcutManagerCompat
import cc.chenx.flclash.common.GlobalState
import cc.chenx.flclash.common.QuickAction
import cc.chenx.flclash.common.action
import cc.chenx.flclash.common.shortcutId
import kotlinx.coroutines.launch

class QuickActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handle(intent)
        finish()
    }

    // A caller that repeats an action before this instance is gone reaches it here, not onCreate.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent) {
        val action = QuickAction.entries.firstOrNull { it.action == intent.action } ?: return
        ShortcutManagerCompat.reportShortcutUsed(this, action.shortcutId)
        GlobalState.launch {
            when (action) {
                QuickAction.START -> ServiceState.handleStartAction()
                QuickAction.STOP -> ServiceState.handleStopAction()
                QuickAction.TOGGLE -> ServiceState.handleToggleAction()
            }
        }
    }
}

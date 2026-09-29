package cc.chenx.flclash.common

import android.content.ComponentName

object Components {
    const val PACKAGE_NAME = "cc.chenx.flclash"

    val mainActivity =
        ComponentName(GlobalState.packageName, "${PACKAGE_NAME}.MainActivity")

    val quickActionActivity =
        ComponentName(GlobalState.packageName, "${PACKAGE_NAME}.QuickActionActivity")

    val serviceBroadcastReceiver =
        ComponentName(GlobalState.packageName, "${PACKAGE_NAME}.ServiceBroadcastReceiver")
}

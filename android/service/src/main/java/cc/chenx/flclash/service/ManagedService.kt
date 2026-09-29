package cc.chenx.flclash.service

import android.app.Service
import cc.chenx.flclash.common.BroadcastAction
import cc.chenx.flclash.common.GlobalState
import cc.chenx.flclash.common.sendBroadcast

interface ManagedService {
    fun start()

    fun stop()
}

internal fun Service.notifyVpnStartRequested() {
    GlobalState.log("VPN start requested")
    BroadcastAction.VPN_START_REQUESTED.sendBroadcast()
}

internal fun Service.notifyVpnRevoked() {
    GlobalState.log("VPN permission revoked")
    BroadcastAction.VPN_REVOKED.sendBroadcast()
}

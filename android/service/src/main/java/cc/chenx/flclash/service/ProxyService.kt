package cc.chenx.flclash.service

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import cc.chenx.flclash.core.Core
import cc.chenx.flclash.service.modules.ServiceModules

class ProxyService : Service(), ManagedService {
    private val modules = ServiceModules(this)
    private val binder = LocalBinder()

    override fun onDestroy() {
        try {
            cleanup()
        } finally {
            super.onDestroy()
        }
    }

    override fun onLowMemory() {
        Core.forceGC()
        super.onLowMemory()
    }

    inner class LocalBinder : Binder() {
        val service: ProxyService
            get() = this@ProxyService
    }

    override fun onBind(intent: Intent): IBinder = binder

    override fun start() {
        try {
            modules.start()
        } catch (error: Exception) {
            stop()
            throw error
        }
    }

    override fun stop() {
        try {
            cleanup()
        } finally {
            stopSelf()
        }
    }

    private fun cleanup() = modules.stop()
}

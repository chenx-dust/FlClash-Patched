package cc.chenx.flclash

import android.content.pm.PackageManager
import android.net.VpnService
import androidx.core.content.ContextCompat
import cc.chenx.flclash.common.GlobalState
import cc.chenx.flclash.models.SharedState
import cc.chenx.flclash.plugins.AppPlugin
import cc.chenx.flclash.plugins.TilePlugin
import cc.chenx.flclash.service.ServiceConfig
import cc.chenx.flclash.service.models.NotificationParams
import cc.chenx.flclash.service.models.VpnOptions
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CoroutineScope

/**
 * The machine owns the arbitration and the transitions; this is only the part that cannot run on a
 * plain JVM, so unit tests can drive the state machine with an in-memory implementation.
 */
internal interface ServiceStateHost {
    val scope: CoroutineScope
    val runTimeMillis: Long
    val homeDirPath: String
    val sdkInt: Int
    val startMessage: String
    val stopMessage: String
    val localNetworkMessage: String

    fun log(message: String)

    fun showToast(message: String)

    fun updateNotificationParams(params: NotificationParams)

    fun loadSharedState(): SharedState

    fun isVpnPermissionGranted(): Boolean

    fun isLocalNetworkPermissionGranted(): Boolean

    fun tile(): TileGateway?

    fun app(): AppGateway?

    suspend fun quickSetup(initParams: String, setupParams: String): Result<String>

    suspend fun startService(options: VpnOptions): Long

    suspend fun stopService()

    suspend fun isVpnServiceActive(): Boolean
}

internal interface TileGateway {
    fun handleStart()

    fun handleStop()
}

internal interface AppGateway {
    fun requestNotificationPermission(callback: (Boolean) -> Unit)

    fun requestLocalNetworkPermission(callback: (Boolean) -> Unit)

    fun prepareVpn(enable: Boolean, callback: (Boolean) -> Unit)

    fun cancelVpnPreparation(callback: (Boolean) -> Unit)
}

internal object AndroidServiceStateHost : ServiceStateHost {
    @Volatile
    private var flutterEngine: FlutterEngine? = null

    override val scope: CoroutineScope
        get() = GlobalState

    override val runTimeMillis: Long
        get() = ServiceController.getRunTimeMillis()

    override val homeDirPath: String
        get() = GlobalState.application.filesDir.path

    override val sdkInt: Int
        get() = android.os.Build.VERSION.SDK_INT

    override val startMessage: String
        get() = GlobalState.application.getString(R.string.start_vpn)

    override val stopMessage: String
        get() = GlobalState.application.getString(R.string.stop_vpn)

    override val localNetworkMessage: String
        get() = GlobalState.application.getString(R.string.local_network_fallback)

    fun attachFlutterEngine(engine: FlutterEngine) {
        flutterEngine = engine
    }

    fun detachFlutterEngine(engine: FlutterEngine) {
        if (flutterEngine === engine) {
            flutterEngine = null
        }
    }

    override fun log(message: String) = GlobalState.log(message)

    override fun showToast(message: String) = GlobalState.application.showToast(message)

    override fun updateNotificationParams(params: NotificationParams) =
        ServiceConfig.updateNotificationParams(params)

    override fun loadSharedState(): SharedState = GlobalState.application.sharedState

    override fun isVpnPermissionGranted(): Boolean =
        VpnService.prepare(GlobalState.application) == null

    override fun isLocalNetworkPermissionGranted(): Boolean =
        sdkInt < LOCAL_NETWORK_SDK ||
            ContextCompat.checkSelfPermission(
                GlobalState.application,
                LOCAL_NETWORK_PERMISSION,
            ) == PackageManager.PERMISSION_GRANTED

    override fun tile(): TileGateway? = flutterEngine?.plugin<TilePlugin>()?.let { plugin ->
        object : TileGateway {
            override fun handleStart() = plugin.handleStart()

            override fun handleStop() = plugin.handleStop()
        }
    }

    override fun app(): AppGateway? = flutterEngine?.plugin<AppPlugin>()?.let { plugin ->
        object : AppGateway {
            override fun requestNotificationPermission(callback: (Boolean) -> Unit) =
                plugin.requestNotificationPermission(callback)

            override fun requestLocalNetworkPermission(callback: (Boolean) -> Unit) =
                plugin.requestLocalNetworkPermission(callback)

            override fun prepareVpn(enable: Boolean, callback: (Boolean) -> Unit) =
                plugin.prepareVpn(enable, callback)

            override fun cancelVpnPreparation(callback: (Boolean) -> Unit) =
                plugin.cancelVpnPreparation(callback)
        }
    }

    override suspend fun quickSetup(initParams: String, setupParams: String): Result<String> =
        ServiceController.quickSetup(initParams, setupParams)

    override suspend fun startService(options: VpnOptions): Long =
        ServiceController.start(options)

    override suspend fun stopService() = ServiceController.stop()

    override suspend fun isVpnServiceActive(): Boolean = ServiceController.isVpnServiceActive()
}

package cc.chenx.flclash.service.modules

import android.app.Service
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkCapabilities.TRANSPORT_SATELLITE
import android.net.NetworkCapabilities.TRANSPORT_USB
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.getSystemService
import cc.chenx.flclash.core.Core
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.util.concurrent.ConcurrentHashMap

private data class NetworkInfo(
    @Volatile var losingUntilMillis: Long = 0,
    @Volatile var dnsList: List<InetAddress> = emptyList(),
    @Volatile var interfaceName: String = "",
    @Volatile var gateway: String = "",
) {
    val priorityPenalty: Int
        get() = if (losingUntilMillis > System.currentTimeMillis()) 10 else 0
}

internal class NetworkObserveModule(private val service: Service) : ServiceModule {

    private val networkInfos = ConcurrentHashMap<Network, NetworkInfo>()
    private val connectivity by lazy {
        service.getSystemService<ConnectivityManager>()
    }
    private val mainHandler = Handler(Looper.getMainLooper())
    private var currentDnsList = listOf<String>()
    private var currentInterfaceName = ""
    private var currentGateway = ""

    private val request = NetworkRequest.Builder().apply {
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            addCapability(NetworkCapabilities.NET_CAPABILITY_FOREGROUND)
        }
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
    }.build()

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            networkInfos[network] = NetworkInfo()
            updateNetwork()
        }

        override fun onLosing(network: Network, maxMsToLive: Int) {
            val info = networkInfos[network] ?: return
            info.losingUntilMillis = System.currentTimeMillis() + maxMsToLive
            updateNetwork()
            if (maxMsToLive > 0) {
                mainHandler.postDelayed({
                    if (networkInfos.containsKey(network)) {
                        updateNetwork()
                    }
                }, maxMsToLive.toLong() + 50)
            }
        }

        override fun onLost(network: Network) {
            networkInfos.remove(network)
            updateNetwork()
        }

        override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
            networkInfos[network]?.apply {
                dnsList = linkProperties.dnsServers
                interfaceName = linkProperties.interfaceName.orEmpty()
                gateway = linkProperties.defaultIpv4Gateway()
            }
            updateNetwork()
        }
    }

    override fun start() {
        updateNetwork()
        connectivity?.registerNetworkCallback(request, callback)
    }

    private fun networkPriority(entry: Map.Entry<Network, NetworkInfo>): Int {
        val capabilities = connectivity?.getNetworkCapabilities(entry.key)
        return when {
            capabilities == null -> 100
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> 90
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> 0
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> 1
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                capabilities.hasTransport(TRANSPORT_USB) -> 2

            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) -> 3
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> 4
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM &&
                capabilities.hasTransport(TRANSPORT_SATELLITE) -> 5

            else -> 20
        } + entry.value.priorityPenalty
    }

    @Synchronized
    private fun updateNetwork() {
        val preferred = networkInfos.asSequence()
            .minByOrNull(::networkPriority)
            ?.value
        updateDns(preferred?.dnsList.orEmpty())
        updateDefaultRoute(preferred?.interfaceName.orEmpty(), preferred?.gateway.orEmpty())
    }

    private fun updateDns(servers: List<InetAddress>) {
        val dnsList = servers
            .map { address -> address.asSocketAddressText(DNS_PORT) }
            .distinct()
        if (dnsList == currentDnsList) {
            return
        }
        currentDnsList = dnsList
        Core.updateDNS(dnsList.joinToString(","))
    }

    private fun updateDefaultRoute(interfaceName: String, gateway: String) {
        if (interfaceName == currentInterfaceName && gateway == currentGateway) {
            return
        }
        currentInterfaceName = interfaceName
        currentGateway = gateway
        Core.updateNetwork(interfaceName, gateway)
    }

    override fun stop() {
        mainHandler.removeCallbacksAndMessages(null)
        try {
            connectivity?.unregisterNetworkCallback(callback)
        } finally {
            networkInfos.clear()
            updateNetwork()
        }
    }
}

private const val DNS_PORT = 53

// netmon takes any gateway that parses as the home router, and an empty one falls back to
// /proc/net/route. On-link routes report `0.0.0.0` or `::`, and IPv6 next hops are link-local.
private fun LinkProperties.defaultIpv4Gateway(): String = routes
    .asSequence()
    .filter { route -> route.isDefaultRoute }
    .mapNotNull { route -> route.gateway as? Inet4Address }
    .firstOrNull { gateway -> !gateway.isAnyLocalAddress }
    ?.hostAddress
    .orEmpty()

private fun InetAddress.asSocketAddressText(port: Int): String = when (this) {
    is Inet6Address -> "[$hostAddress]:$port"
    is Inet4Address -> "$hostAddress:$port"
    else -> error("Unsupported address type: ${javaClass.name}")
}

package com.follow.clash.models

import com.follow.clash.service.models.VpnOptions
import com.google.gson.annotations.SerializedName

data class SharedState(
    val currentProfileName: String = "FlClash",
    val onlyStatisticsProxy: Boolean = false,
    val networkSpeedNotification: Boolean = false,
    val vpnOptions: VpnOptions? = null,
    val setupParams: SetupParams? = null,
)

data class SetupParams(
    @SerializedName("test-url")
    val testUrl: String,
    @SerializedName("selected-map")
    val selectedMap: Map<String, String>,
)

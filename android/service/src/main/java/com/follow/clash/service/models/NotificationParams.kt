package com.follow.clash.service.models

data class NotificationParams(
    val title: String = "FlClash",
    val onlyStatisticsProxy: Boolean = false,
    val showStopAction: Boolean = true,
    val networkSpeedNotification: Boolean = false,
)

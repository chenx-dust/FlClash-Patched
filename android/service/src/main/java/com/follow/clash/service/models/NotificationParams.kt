package com.follow.clash.service.models

data class NotificationParams(
    val title: String = "FlClash",
    val onlyStatisticsProxy: Boolean = false,
    val networkSpeedNotification: Boolean = false,
)

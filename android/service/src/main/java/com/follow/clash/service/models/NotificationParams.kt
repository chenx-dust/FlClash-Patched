package com.follow.clash.service.models

data class NotificationParams(
    val title: String = "FlClash",
    val stopText: String = "STOP",
    val connectedText: String = "Connected",
    val onlyStatisticsProxy: Boolean = false,
    val networkSpeedNotification: Boolean = false,
)

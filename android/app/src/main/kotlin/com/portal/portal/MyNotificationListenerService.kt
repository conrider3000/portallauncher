package com.portal.portal

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.content.Intent
import android.content.Context

class MyNotificationListenerService : NotificationListenerService() {
    companion object {
        var activeNotificationsList = mutableListOf<Map<String, String>>()
        var instance: MyNotificationListenerService? = null
        var onNotificationChanged: (() -> Unit)? = null
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        updateNotifications()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn)
        updateNotifications()
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        super.onNotificationRemoved(sbn)
        updateNotifications()
    }

    fun updateNotifications() {
        try {
            val sbns = activeNotifications ?: return
            val list = mutableListOf<Map<String, String>>()
            for (sbn in sbns) {
                val extras = sbn.notification.extras
                val title = extras.getCharSequence("android.title")?.toString() ?: ""
                val text = extras.getCharSequence("android.text")?.toString() ?: ""
                val pack = sbn.packageName
                val key = sbn.key
                if (title.isNotEmpty() || text.isNotEmpty()) {
                    list.add(mapOf(
                        "key" to key,
                        "packageName" to pack,
                        "title" to title,
                        "text" to text,
                        "postTime" to sbn.postTime.toString()
                    ))
                }
            }
            activeNotificationsList = list
            onNotificationChanged?.invoke()
        } catch (e: Exception) {
            // Ignore
        }
    }
}

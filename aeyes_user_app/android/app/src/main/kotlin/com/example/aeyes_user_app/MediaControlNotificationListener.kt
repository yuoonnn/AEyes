package com.example.aeyes_user_app

import android.service.notification.NotificationListenerService

class MediaControlNotificationListener : NotificationListenerService() {
    companion object {
        @Volatile
        var isEnabled: Boolean = false
            private set

        fun updateEnabled(state: Boolean) {
            isEnabled = state
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        updateEnabled(true)
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        updateEnabled(false)
    }

    override fun onDestroy() {
        super.onDestroy()
        updateEnabled(false)
    }
}

package com.roost.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    // Referenced by AndroidManifest.xml's
    // com.google.firebase.messaging.default_notification_channel_id.
    // Declaring that meta-data alone doesn't create the channel -- on
    // API 26+, a notification posted to a channel that doesn't exist
    // yet can silently fail to display, so this must run before any
    // push notification arrives.
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "roost_default_channel",
                "Roost Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Messages, listing updates, and account alerts"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}

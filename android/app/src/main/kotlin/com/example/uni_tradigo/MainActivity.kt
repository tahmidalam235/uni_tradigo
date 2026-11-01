package com.example.uni_tradigo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    /**
     * Creates the channel that Firebase posts purchase and chat
     * notifications to.
     *
     * On Android 8.0+ a notification that targets a channel that does
     * not exist is silently dropped, so the channel has to be created
     * before the first push arrives. It is created here, on app start,
     * and is referenced from AndroidManifest.xml via
     * `default_notification_channel_id`.
     *
     * The id matches the manifest value exactly — the two must agree or
     * the notification will not be shown.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Marketplace alerts",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Purchase and chat notifications from Uni-Tradigo"
            enableVibration(true)
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }

    private companion object {
        const val CHANNEL_ID = "uni_tradigo_notifications"
    }
}

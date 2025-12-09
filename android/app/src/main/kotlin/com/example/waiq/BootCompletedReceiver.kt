package com.example.waiq

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Ensures WorkManager is re-initialized after device reboot by cold-starting
 * the Flutter host Activity once (silent, FLAG_ACTIVITY_NEW_TASK).
 */
class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        try {
            val launch = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(launch)
            Log.i("BootReceiver", "Launched app to re-init background tasks after boot")
        } catch (e: Exception) {
            Log.w("BootReceiver", "Failed to launch app after boot: ${e.message}")
        }
    }
}

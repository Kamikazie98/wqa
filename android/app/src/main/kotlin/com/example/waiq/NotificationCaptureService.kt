package com.example.waiq

import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Captures posted notifications (title/body only) and appends them into
 * FlutterSharedPreferences under key "notif.buffer" so Flutter can read them.
 */
class NotificationCaptureService : NotificationListenerService() {

    private val PREFS_NAME = "FlutterSharedPreferences"
    private val NOTIF_KEY = "notif.buffer"

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d("NotifCapture", "onListenerConnected")
        try {
            activeNotifications?.forEach { sbn ->
                sbn?.let { cacheNotification(it) }
            }
        } catch (e: Exception) {
            Log.w("NotifCapture", "Failed to cache existing notifications: ${e.message}")
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        cacheNotification(sbn)
    }

    private fun cacheNotification(sbn: StatusBarNotification) {
        try {
            Log.d("NotifCapture", "cacheNotification for ${sbn.packageName}")

            // نوتیف خود اپ رو نادیده بگیر
            if (sbn.packageName == packageName) {
                Log.d("NotifCapture", "Skipping own package notification")
                return
            }

            // نوتیف‌های ongoing (مثلاً سرویس دائمی) رو نادیده بگیر
            if (sbn.isOngoing) {
                Log.d("NotifCapture", "Skipping ongoing notification")
                return
            }

            val extras = sbn.notification.extras
            val title = extras.getCharSequence("android.title")?.toString() ?: ""
            val body = extractBody(extras)

            if (title.isBlank() && body.isBlank()) {
                Log.d("NotifCapture", "Both title and body blank, skip")
                return
            }

            // فیلتر نوتیف‌های تبلیغاتی (به‌خصوص SMS تبلیغاتی)
            if (isPromotional(title, body, sbn.packageName ?: "")) {
                Log.d("NotifCapture", "Skipping promotional notification")
                return
            }
            if (sbn.packageName == "com.lenovo.anyshare.gps" || sbn.packageName == "com.xiaomi.mirror") {
                Log.d("NotifCapture", "Skipping ANYSHARE notification")
                return
            }
            val prefs = applicationContext.getSharedPreferences(
                PREFS_NAME,
                MODE_PRIVATE
            )

            val raw = prefs.getString(NOTIF_KEY, "[]") ?: "[]"
            Log.d("NotifCapture", "Read raw buffer: $raw")

            val arr = JSONArray(raw)
            Log.d("NotifCapture", "Buffer length before add: ${arr.length()}")

            // محدود نگه‌داشتن بافر
            if (arr.length() >= 20) {
                Log.d("NotifCapture", "Trimming old items in buffer")
                for (i in 0 until 5) {
                    if (arr.length() > 0) arr.remove(0)
                }
            }

            val item = JSONObject().apply {
                put("title", title)
                put("body", body)
                put("pkg", sbn.packageName ?: "")
                put("ts", System.currentTimeMillis())
                val category = sbn.notification.category
                if (!category.isNullOrBlank()) {
                    put("category", category)
                }
            }

            Log.d("NotifCapture", "Adding item: $item")

            arr.put(item)
            Log.d("NotifCapture", "Buffer length after add: ${arr.length()}")

            val newRaw = arr.toString()
            Log.d("NotifCapture", "Writing new buffer: $newRaw")

            prefs.edit()
                .putString(NOTIF_KEY, newRaw)
                .apply()

        } catch (e: Exception) {
            Log.e("NotifCapture", "Failed to cache notification", e)
        }
    }

    private fun extractBody(extras: Bundle): String {
        val direct =
            extras.getCharSequence("android.text")?.toString()
                ?: extras.getCharSequence("android.bigText")?.toString()
                ?: extras.getCharSequence("android.infoText")?.toString()

        if (!direct.isNullOrBlank()) return direct

        val lines = extras.getCharSequenceArray("android.textLines")
        if (lines != null && lines.isNotEmpty()) {
            return lines.joinToString(" ") { it.toString() }
        }
        return ""
    }

    // تشخیص خیلی ساده/هیورستیک تبلیغاتی‌ها
    private fun isPromotional(title: String, body: String, pkg: String): Boolean {
        val text = (title + " " + body).lowercase()

        val isSmsApp =
            pkg.contains("messaging") || pkg.contains("sms") || pkg.contains("mms")

        val promoKeywords = listOf(
            "لغو11", "لغو 11", "لغو ارسال",
            "تخفیف", "هدیه", "جایزه",
            "شارژ", "بسته اینترنت", "پکیج اینترنت",
            "همراه اول", "ایرانسل", "رایتل",
            "% تخفیف", "off"
        )

        return isSmsApp && promoKeywords.any { text.contains(it.lowercase()) }
    }
}

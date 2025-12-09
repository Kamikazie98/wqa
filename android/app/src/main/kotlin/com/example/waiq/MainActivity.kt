package com.example.waiq

import android.content.ContentResolver
import android.content.ComponentName
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Bundle
import android.provider.CalendarContract
import android.provider.Settings
import androidx.annotation.NonNull
import android.app.usage.UsageStatsManager
import android.app.usage.UsageStats
import android.app.AppOpsManager
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Locale

class MainActivity : FlutterActivity() {

    private val channel = "native/automation"
    private val messageChannel = "native/messages"
    private val openAppChannel = "waiq/notifications"   // 👈 کانال جدید برای باز کردن اپ‌ها

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ===== کانال automation قبلی =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBusyEvents" -> {
                        val args = call.arguments as? Map<*, *>
                        val start = args?.get("start")?.toString()
                        val end = args?.get("end")?.toString()
                        if (start == null || end == null) {
                            result.error("invalid_args", "start/end required", null)
                        } else {
                            val events = queryBusyEvents(contentResolver, start, end)
                            result.success(events)
                        }
                    }
                    "getWifiSsid" -> {
                        result.success(currentSsid())
                    }
                    "startSenseService" -> {
                        startSenseService()
                        result.success(true)
                    }
                    "stopSenseService" -> {
                        stopSenseService()
                        result.success(true)
                    }
                    "getUsageStats" -> {
                        val stats = queryUsageStats()
                        result.success(stats)
                    }
                    "cacheUsageStats" -> {
                        cacheUsageStats()
                        result.success(true)
                    }
                    "isNotificationListenerEnabled" -> {
                        result.success(isNotificationListenerEnabled())
                    }
                    else -> result.notImplemented()
                }
            }

        // ===== کانال پیام‌ها (MessageReader) قبلی =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, messageChannel)
            .setMethodCallHandler { call, result ->
                val messageReader = MessageReader(this)
                when (call.method) {
                    "getPendingMessages" -> {
                        val limit = (call.arguments as? Int) ?: 50
                        val messages = messageReader.getPendingMessages(limit)
                        result.success(messages)
                    }
                    "getAllMessages" -> {
                        val limit = (call.arguments as? Int) ?: 100
                        val messages = messageReader.getAllMessages(limit)
                        result.success(messages)
                    }
                    "getMessageThreads" -> {
                        val threads = messageReader.getMessageThreads()
                        result.success(threads)
                    }
                    "getMessagesFromContact" -> {
                        val phoneNumber = call.arguments as? String ?: ""
                        val messages = messageReader.getMessagesFromContact(phoneNumber)
                        result.success(messages)
                    }
                    "markAsRead" -> {
                        val messageId = call.arguments as? String ?: ""
                        val success = messageReader.markAsRead(messageId)
                        result.success(success)
                    }
                    "deleteMessage" -> {
                        val messageId = call.arguments as? String ?: ""
                        val success = messageReader.deleteMessage(messageId)
                        result.success(success)
                    }
                    "getUnreadCount" -> {
                        val count = messageReader.getUnreadCount()
                        result.success(count)
                    }
                    else -> result.notImplemented()
                }
            }

        // ===== کانال جدید برای باز کردن اپ مربوط به نوتیف =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, openAppChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "openApp") {
                    val pkg = call.argument<String>("package")
                    if (pkg.isNullOrBlank()) {
                        result.error("NO_PACKAGE", "Package name is null/blank", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent: Intent? = packageManager.getLaunchIntentForPackage(pkg)
                        if (intent != null) {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("NO_ACTIVITY", "No launch intent for package $pkg", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    // ===== متدهای کمکی قبلی‌ات بدون تغییر =====

    private fun queryBusyEvents(
        resolver: ContentResolver,
        startIso: String,
        endIso: String
    ): List<Map<String, Any>> {
        return try {
            val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
            val startMillis = format.parse(startIso)?.time ?: return emptyList()
            val endMillis = format.parse(endIso)?.time ?: return emptyList()
            val uri: Uri = CalendarContract.Events.CONTENT_URI
            val projection = arrayOf(
                CalendarContract.Events.TITLE,
                CalendarContract.Events.DTSTART,
                CalendarContract.Events.DTEND
            )
            val selection =
                "(${CalendarContract.Events.DTSTART} >= ?) AND (${CalendarContract.Events.DTSTART} <= ?)"
            val selectionArgs = arrayOf(startMillis.toString(), endMillis.toString())
            val cursor: Cursor? = resolver.query(
                uri,
                projection,
                selection,
                selectionArgs,
                "${CalendarContract.Events.DTSTART} ASC"
            )
            val result = mutableListOf<Map<String, Any>>()
            cursor?.use { c ->
                val titleIdx = c.getColumnIndex(CalendarContract.Events.TITLE)
                val startIdx = c.getColumnIndex(CalendarContract.Events.DTSTART)
                val endIdx = c.getColumnIndex(CalendarContract.Events.DTEND)
                while (c.moveToNext()) {
                    val title = if (titleIdx >= 0) c.getString(titleIdx) ?: "" else ""
                    val s = if (startIdx >= 0) c.getLong(startIdx) else 0L
                    val e = if (endIdx >= 0) c.getLong(endIdx) else s
                    result.add(
                        mapOf(
                            "title" to title,
                            "start" to s,
                            "end" to e
                        )
                    )
                }
            }
            result
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun currentSsid(): String {
        return try {
            val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
            val info = wifiManager.connectionInfo
            val ssid = info?.ssid
            if (ssid.isNullOrBlank() || ssid == "<unknown ssid>") "" else ssid.replace("\"", "")
        } catch (_: Exception) {
            ""
        }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        return try {
            val component = ComponentName(packageName, NotificationCaptureService::class.java.name)
            val enabledListeners =
                Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            if (enabledListeners.isNullOrBlank()) return false
            enabledListeners.split(":").any { entry ->
                entry.equals(component.flattenToString(), ignoreCase = true) ||
                    entry.contains(packageName, ignoreCase = true)
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun startSenseService() {
        val intent = Intent(this, ForegroundSenseService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopSenseService() {
        val intent = Intent(this, ForegroundSenseService::class.java)
        stopService(intent)
    }

    private fun queryUsageStats(): List<Map<String, Any>> {
        return try {
            if (!hasUsagePermission()) return emptyList()
            val usm = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
            val end = System.currentTimeMillis()
            val start = end - 24 * 60 * 60 * 1000L
            val stats: List<UsageStats> =
                usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
            val filtered = stats
                .filter { it.totalTimeInForeground > 0 }
                .sortedByDescending { it.totalTimeInForeground }
                .take(15)
            filtered.map {
                mapOf(
                    "package" to it.packageName,
                    "minutes" to (it.totalTimeInForeground / 60000L)
                )
            }
        } catch (_: SecurityException) {
            emptyList()
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun cacheUsageStats() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val stats = queryUsageStats()
        prefs.edit()
            .putString("flutter.usage.buffer", org.json.JSONArray(stats).toString())
            .apply()
    }

    private fun hasUsagePermission(): Boolean {
        return try {
            val appOps = getSystemService(APP_OPS_SERVICE) as AppOpsManager
            val mode = appOps.unsafeCheckOpNoThrow(
                "android:get_usage_stats",
                Process.myUid(),
                packageName
            )
            mode == AppOpsManager.MODE_ALLOWED
        } catch (_: Exception) {
            false
        }
    }
}

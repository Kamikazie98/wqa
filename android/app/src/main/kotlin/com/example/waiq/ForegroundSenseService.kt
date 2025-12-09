package com.example.waiq

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject

class ForegroundSenseService : Service() {

    private val channelId = "waiq.sense"
    private val notificationId = 4242
    private val handler = Handler(Looper.getMainLooper())
    private val intervalMs = 5 * 60 * 1000L

    private val pollRunnable = object : Runnable {
        override fun run() {
            try {
                cacheSensors()
            } catch (e: Exception) {
                Log.w("SenseService", "poll error: ${e.message}")
            } finally {
                handler.postDelayed(this, intervalMs)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()

        // ✅ قبل از استارت FGS، مجوز لوکیشن را چک کن
        if (!hasLocationPermission()) {
            Log.w("SenseService", "Missing location permission, stopping service")
            stopSelf()
            return
        }

        createChannel()

        val notification = buildNotification("مدیریت هوشمند فعال")

        // ✅ برای FGS از نوع لوکیشن، روی Android Q+ باید type را هم ست کنیم
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                notificationId,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(notificationId, notification)
        }

        handler.post(pollRunnable)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(pollRunnable)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val coarse = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        return fine || coarse
    }

    private fun buildNotification(text: String): Notification {
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("Waiq Assistant")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setOngoing(true)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Waiq Sense",
                NotificationManager.IMPORTANCE_LOW
            )
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun cacheSensors() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val wifi = currentSsid()
        val loc = currentLocation()

        val rawCtx = prefs.getString("flutter.automation.mode.context", "{}") ?: "{}"
        val ctx = try {
            JSONObject(rawCtx)
        } catch (_: Exception) {
            JSONObject()
        }

        if (wifi.isNotEmpty()) ctx.put("wifi", wifi)
        loc?.let {
            ctx.put("lat", it.latitude)
            ctx.put("lon", it.longitude)
        }

        prefs.edit()
            .putString("flutter.automation.mode.context", ctx.toString())
            .putString("flutter.sense.wifi", wifi)
            .putString("flutter.sense.location", "${loc?.latitude},${loc?.longitude}")
            .apply()
    }

    private fun currentSsid(): String {
        return try {
            val wifiManager =
                applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val info = wifiManager.connectionInfo
            val ssid = info?.ssid
            if (ssid.isNullOrBlank() || ssid == "<unknown ssid>") "" else ssid.replace("\"", "")
        } catch (_: Exception) {
            ""
        }
    }

    private fun currentLocation(): Location? {
        return try {
            val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val providers =
                listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
            providers.mapNotNull { provider ->
                lm.getLastKnownLocation(provider)
            }.maxByOrNull { it.time }
        } catch (_: SecurityException) {
            null
        } catch (_: Exception) {
            null
        }
    }
}

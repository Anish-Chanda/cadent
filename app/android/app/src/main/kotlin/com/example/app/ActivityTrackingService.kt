package com.example.app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import kotlin.math.roundToInt

class ActivityTrackingService : Service(), LocationListener {
    private lateinit var locationManager: LocationManager
    private val handler = Handler(Looper.getMainLooper())

    private var activityName = "Activity"
    private var activityType = "running"
    private var useMetricUnits = true
    private var isRecording = false
    private var isPaused = false
    private var sessionStartedAtMs = 0L
    private var startRealtimeMs = 0L
    private var accumulatedElapsedMs = 0L
    private var distanceMeters = 0.0
    private var lastLocation: Location? = null
    private val positions = mutableListOf<Map<String, Any?>>()

    private val ticker = object : Runnable {
        override fun run() {
            if (isRecording || isPaused) {
                publishSnapshot(updateNotification = true)
                handler.postDelayed(this, 1000L)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                activityName = intent.getStringExtra(EXTRA_ACTIVITY_NAME) ?: "Activity"
                activityType = intent.getStringExtra(EXTRA_ACTIVITY_TYPE) ?: "running"
                useMetricUnits = intent.getBooleanExtra(EXTRA_USE_METRIC_UNITS, true)
                startNewTrackingSession()
            }
            ACTION_PAUSE -> pauseTracking()
            ACTION_RESUME -> resumeTracking()
            ACTION_STOP -> stopTracking()
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        if (isRecording || isPaused) {
            publishSnapshot(updateNotification = true)
        }
    }

    override fun onDestroy() {
        stopLocationUpdates()
        handler.removeCallbacks(ticker)
        super.onDestroy()
    }

    override fun onLocationChanged(location: Location) {
        if (!isRecording) return

        lastLocation?.let { previous ->
            val segmentDistance = previous.distanceTo(location).toDouble()
            if (!segmentDistance.isNaN() && !segmentDistance.isInfinite() && segmentDistance >= 0.0) {
                distanceMeters += segmentDistance
            }
        }

        lastLocation = location
        positions.add(locationToMap(location))
        publishSnapshot(updateNotification = true)
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

    override fun onProviderEnabled(provider: String) = Unit

    override fun onProviderDisabled(provider: String) {
        publishSnapshot(updateNotification = true)
    }

    private fun startNewTrackingSession() {
        isRecording = true
        isPaused = false
        sessionStartedAtMs = System.currentTimeMillis()
        startRealtimeMs = sessionStartedAtMs
        accumulatedElapsedMs = 0L
        distanceMeters = 0.0
        lastLocation = null
        positions.clear()

        startForeground(NOTIFICATION_ID, buildNotification())
        startLocationUpdates()
        handler.removeCallbacks(ticker)
        handler.post(ticker)
        publishSnapshot(updateNotification = true)
    }

    private fun pauseTracking() {
        if (!isRecording) return

        accumulatedElapsedMs = elapsedMs()
        isRecording = false
        isPaused = true
        stopLocationUpdates()
        publishSnapshot(updateNotification = true)
    }

    private fun resumeTracking() {
        if (!isPaused) return

        isRecording = true
        isPaused = false
        startRealtimeMs = System.currentTimeMillis()
        startLocationUpdates()
        handler.removeCallbacks(ticker)
        handler.post(ticker)
        publishSnapshot(updateNotification = true)
    }

    private fun stopTracking() {
        isRecording = false
        isPaused = false
        stopLocationUpdates()
        handler.removeCallbacks(ticker)
        latestSnapshot = buildSnapshot(includePositions = false)
        latestFullSnapshot = buildSnapshot(includePositions = true)
        publishSnapshot(updateNotification = false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun startLocationUpdates() {
        if (
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val provider = when {
            locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ->
                LocationManager.GPS_PROVIDER
            locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ->
                LocationManager.NETWORK_PROVIDER
            else -> null
        }

        if (provider != null) {
            locationManager.requestLocationUpdates(
                provider,
                LOCATION_INTERVAL_MS,
                0f,
                this,
                Looper.getMainLooper(),
            )
        }
    }

    private fun stopLocationUpdates() {
        locationManager.removeUpdates(this)
    }

    private fun publishSnapshot(updateNotification: Boolean) {
        val snapshot = buildSnapshot(includePositions = false)
        latestSnapshot = snapshot
        latestFullSnapshot = buildSnapshot(includePositions = true)
        TrackingEventBus.emit(snapshot)

        if (updateNotification && (isRecording || isPaused)) {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID, buildNotification())
        }
    }

    private fun buildSnapshot(includePositions: Boolean): Map<String, Any?> {
        val snapshot = mutableMapOf<String, Any?>(
            "activityType" to activityType,
            "activityName" to activityName,
            "isRecording" to isRecording,
            "isPaused" to isPaused,
            "startTimestamp" to sessionStartedAtMs,
            "elapsedSeconds" to (elapsedMs() / 1000L).toInt(),
            "distanceMeters" to distanceMeters,
            "currentSpeedMetersPerSecond" to currentSpeedMetersPerSecond(),
            "lastPosition" to positions.lastOrNull(),
        )

        if (includePositions) {
            snapshot["positions"] = positions.toList()
        }

        return snapshot
    }

    private fun buildNotification(): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_OPEN_RECORDER
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val elapsed = formatElapsed(elapsedMs() / 1000L)
        val distance = formatDistance(distanceMeters)
        val effortMetric = formatEffortMetric(currentSpeedMetersPerSecond())
        val status = if (isPaused) "Paused" else "Recording"
        val title = "$status $activityName"
        val text = "Time $elapsed | Distance $distance | $effortMetric"

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_tracking)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Activity tracking",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Shows live activity tracking details while Cadent records."
            setShowBadge(false)
        }

        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }

    private fun locationToMap(location: Location): Map<String, Any?> {
        return mapOf(
            "lat" to location.latitude,
            "lon" to location.longitude,
            "timestamp" to location.time,
            "accuracy" to location.accuracy.toDouble(),
            "altitude" to location.altitude,
            "speed" to if (location.hasSpeed()) location.speed.toDouble() else 0.0,
            "heading" to if (location.hasBearing()) location.bearing.toDouble() else 0.0,
        )
    }

    private fun elapsedMs(): Long {
        return if (isRecording) {
            accumulatedElapsedMs + (System.currentTimeMillis() - startRealtimeMs)
        } else {
            accumulatedElapsedMs
        }
    }

    private fun currentSpeedMetersPerSecond(): Double {
        if (positions.size < 2) return 0.0

        val lastTimestamp = (positions.last()["timestamp"] as? Long) ?: return 0.0
        if (System.currentTimeMillis() - lastTimestamp > 5000L) return 0.0

        val sample = positions.takeLast(5)
        if (sample.size < 2) return 0.0

        val first = sample.first()
        val last = sample.last()
        val firstTime = (first["timestamp"] as? Long) ?: return 0.0
        val lastTime = (last["timestamp"] as? Long) ?: return 0.0
        val seconds = (lastTime - firstTime) / 1000.0
        if (seconds < 2.0) return 0.0

        val result = FloatArray(1)
        Location.distanceBetween(
            first["lat"] as Double,
            first["lon"] as Double,
            last["lat"] as Double,
            last["lon"] as Double,
            result,
        )

        val distance = result[0].toDouble()
        if (distance < 1.0) return 0.0

        val speed = distance / seconds
        return if (speed < 0.2) 0.0 else speed
    }

    private fun formatElapsed(totalSeconds: Long): String {
        val hours = totalSeconds / 3600L
        val minutes = (totalSeconds % 3600L) / 60L
        val seconds = totalSeconds % 60L
        return "%02d:%02d:%02d".format(hours, minutes, seconds)
    }

    private fun formatDistance(meters: Double): String {
        if (!useMetricUnits) {
            val miles = meters * 0.000621371
            return "%.2f mi".format(miles)
        }

        return if (meters >= 1000.0) {
            "%.2f km".format(meters / 1000.0)
        } else {
            "${meters.roundToInt()} m"
        }
    }

    private fun formatEffortMetric(speedMetersPerSecond: Double): String {
        return if (activityType == "running") {
            "Pace ${formatPace(speedMetersPerSecond)}"
        } else {
            "Speed ${formatSpeed(speedMetersPerSecond)}"
        }
    }

    private fun formatSpeed(speedMetersPerSecond: Double): String {
        return if (useMetricUnits) {
            "%.1f km/h".format(speedMetersPerSecond * 3.6)
        } else {
            "%.1f mph".format(speedMetersPerSecond * 2.236936)
        }
    }

    private fun formatPace(speedMetersPerSecond: Double): String {
        if (speedMetersPerSecond < 0.2) {
            return if (useMetricUnits) "--/km" else "--/mi"
        }

        val secondsPerUnit = if (useMetricUnits) {
            1000.0 / speedMetersPerSecond
        } else {
            1609.344 / speedMetersPerSecond
        }
        val roundedSeconds = secondsPerUnit.roundToInt()
        val minutes = roundedSeconds / 60
        val seconds = roundedSeconds % 60
        val unit = if (useMetricUnits) "km" else "mi"
        return "%d:%02d/%s".format(minutes, seconds, unit)
    }

    companion object {
        const val ACTION_OPEN_RECORDER = "com.example.app.tracking.OPEN_RECORDER"

        private const val ACTION_START = "com.example.app.tracking.START"
        private const val ACTION_PAUSE = "com.example.app.tracking.PAUSE"
        private const val ACTION_RESUME = "com.example.app.tracking.RESUME"
        private const val ACTION_STOP = "com.example.app.tracking.STOP"
        private const val EXTRA_ACTIVITY_NAME = "activityName"
        private const val EXTRA_ACTIVITY_TYPE = "activityType"
        private const val EXTRA_USE_METRIC_UNITS = "useMetricUnits"
        private const val NOTIFICATION_CHANNEL_ID = "cadent_activity_tracking_live"
        private const val NOTIFICATION_ID = 2501
        private const val LOCATION_INTERVAL_MS = 1000L

        var latestSnapshot: Map<String, Any?>? = null
        var latestFullSnapshot: Map<String, Any?>? = null

        fun start(
            context: Context,
            activityType: String,
            activityName: String,
            useMetricUnits: Boolean,
        ) {
            val intent = Intent(context, ActivityTrackingService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_ACTIVITY_TYPE, activityType)
                putExtra(EXTRA_ACTIVITY_NAME, activityName)
                putExtra(EXTRA_USE_METRIC_UNITS, useMetricUnits)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun pause(context: Context) {
            sendAction(context, ACTION_PAUSE)
        }

        fun resume(context: Context) {
            sendAction(context, ACTION_RESUME)
        }

        fun stop(context: Context) {
            sendAction(context, ACTION_STOP)
        }

        private fun sendAction(context: Context, actionName: String) {
            val intent = Intent(context, ActivityTrackingService::class.java).apply {
                action = actionName
            }
            context.startService(intent)
        }
    }
}

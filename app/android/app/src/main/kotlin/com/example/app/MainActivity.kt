package com.example.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val trackingPermissionsChannel = "cadent/tracking_permissions"
    private val trackingServiceChannel = "cadent/activity_tracking_service"
    private val trackingEventsChannel = "cadent/activity_tracking_events"
    private val navigationEventsChannel = "cadent/navigation_events"
    private val postNotificationsRequestCode = 2401
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            trackingPermissionsChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPostNotificationsPermission" -> requestPostNotificationsPermission(result)
                "openNotificationSettings" -> openNotificationSettings(result)
                "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                "requestIgnoreBatteryOptimizations" -> requestIgnoreBatteryOptimizations(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            trackingServiceChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val activityType = call.argument<String>("activityType") ?: "running"
                    val activityName = call.argument<String>("activityName") ?: "Activity"
                    val useMetricUnits = call.argument<Boolean>("useMetricUnits") ?: true
                    ActivityTrackingService.start(
                        this,
                        activityType,
                        activityName,
                        useMetricUnits
                    )
                    result.success(true)
                }
                "pause" -> {
                    ActivityTrackingService.pause(this)
                    result.success(true)
                }
                "resume" -> {
                    ActivityTrackingService.resume(this)
                    result.success(true)
                }
                "stop" -> {
                    ActivityTrackingService.stop(this)
                    result.success(true)
                }
                "getSnapshot" -> result.success(
                    ActivityTrackingService.latestFullSnapshot
                        ?: ActivityTrackingService.latestSnapshot
                )
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            trackingEventsChannel
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    TrackingEventBus.attach(events)
                }

                override fun onCancel(arguments: Any?) {
                    TrackingEventBus.detach()
                }
            }
        )

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            navigationEventsChannel
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NavigationIntentBus.attach(events)
                    handleNavigationIntent(intent)
                }

                override fun onCancel(arguments: Any?) {
                    NavigationIntentBus.detach()
                }
            }
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNavigationIntent(intent)
    }

    private fun handleNavigationIntent(intent: Intent?) {
        if (intent?.action == ActivityTrackingService.ACTION_OPEN_RECORDER) {
            NavigationIntentBus.emit("recorder")
            intent.action = null
        }
    }

    private fun requestPostNotificationsPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        if (
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        if (pendingNotificationPermissionResult != null) {
            result.error(
                "request_in_progress",
                "A notification permission request is already in progress.",
                null
            )
            return
        }

        pendingNotificationPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            postNotificationsRequestCode
        )
    }

    private fun openNotificationSettings(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startActivity(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
            )
        } else {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = android.net.Uri.parse("package:$packageName")
                }
            )
        }
        result.success(true)
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true

        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(true)
            return
        }

        if (isIgnoringBatteryOptimizations()) {
            result.success(true)
            return
        }

        startActivity(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
        )
        result.success(true)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == postNotificationsRequestCode) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingNotificationPermissionResult?.success(granted)
            pendingNotificationPermissionResult = null
        }
    }
}

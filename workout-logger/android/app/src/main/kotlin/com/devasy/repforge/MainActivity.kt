package com.devasy.repforge

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "repforge/rest_alert")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT < 33 ||
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                        ) {
                            result.success(RestAlertReceiver.notificationsAllowed(this))
                        } else if (permissionResult != null) {
                            result.error("permission_pending", "A notification permission request is pending", null)
                        } else {
                            permissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 9041)
                        }
                    }
                    "schedule" -> {
                        val deadline = call.argument<Number>("deadlineMillis")?.toLong()
                        if (deadline == null) {
                            result.error("invalid_deadline", "A rest deadline is required", null)
                        } else {
                            RestAlertReceiver.schedule(
                                this, deadline,
                                call.argument<Boolean>("sound") == true,
                                call.argument<Boolean>("vibration") == true
                            )
                            result.success(null)
                        }
                    }
                    "cancel" -> {
                        RestAlertReceiver.cancel(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 9041) {
            permissionResult?.success(
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED &&
                    RestAlertReceiver.notificationsAllowed(this)
            )
            permissionResult = null
        }
    }
}

package app.ibada

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class HomeActivity : FlutterActivity() {
    private var notificationReply: MethodChannel.Result? = null
    private var mediaReply: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PrayerAlarm.BRIDGE)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "status" -> result.success(
                            if (call.arguments == true) mapOf(
                                "notifications" to PrayerAlarm.notificationAllowed(this),
                                "exact" to PrayerAlarm.exact(this),
                                "fullScreen" to PrayerAlarm.fullScreen(this),
                            ) else PrayerAlarm.status(this),
                        )
                        "mediaStatus" -> result.success(PrayerAlertMedia.status(this))
                        "pickSound", "pickImage", "pickTone" -> pickMedia(call.method, result)
                        "resetSound", "resetImage", "setSoundPreset", "setImagePreset" -> {
                            check(mediaReply == null) { "انتظر حتى يكتمل اختيار الملف." }
                            val kind = if (call.method.contains("Sound")) "sound" else "image"
                            val preset = if (call.method.startsWith("reset")) null else call.arguments as String
                            PrayerAlertMedia.select(this, kind, preset)
                            result.success(null)
                        }
                        "replace" -> {
                            PrayerAlarm.replace(this, call.arguments as Map<*, *>)
                            result.success(null)
                        }
                        "request" -> request(call.arguments as String, result)
                        "test" -> {
                            PrayerAlarm.test(this, call.arguments as? Boolean ?: true)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("PRAYER_ALARM", error.message, null)
                }
            }
    }

    private fun pickMedia(action: String, result: MethodChannel.Result) {
        check(mediaReply == null) { "انتظر حتى يكتمل اختيار الملف." }
        val code = when (action) {
            "pickTone" -> 1404
            "pickSound" -> 1405
            else -> 1406
        }
        val picker = if (action == "pickTone") {
            Intent(RingtoneManager.ACTION_RINGTONE_PICKER)
                .putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, false)
        } else {
            Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                .setType(if (action == "pickSound") "audio/*" else "image/*")
        }
        try {
            startActivityForResult(picker, code)
            mediaReply = result
        } catch (_: android.content.ActivityNotFoundException) {
            result.error("PRAYER_MEDIA", "تعذّر فتح منتقي الملفات على الجهاز.", null)
        }
    }

    @Deprecated("Activity result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode !in 1404..1406) return
        val reply = mediaReply ?: return
        @Suppress("DEPRECATION")
        val uri = if (requestCode == 1404) data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            else data?.data
        if (resultCode != RESULT_OK || uri == null) {
            mediaReply = null
            reply.success(null)
            return
        }
        Thread {
            val failure = try {
                PrayerAlertMedia.import(applicationContext, uri, if (requestCode == 1406) "image" else "sound",
                    systemTone = requestCode == 1404)
                null
            } catch (error: Exception) {
                when (error) {
                    is IllegalArgumentException, is IllegalStateException -> error.message
                    else -> null
                } ?: "تعذّرت قراءة الملف المختار."
            }
            runOnUiThread {
                mediaReply = null
                if (!isDestroyed) {
                    if (failure == null) reply.success(null) else reply.error("PRAYER_MEDIA", failure, null)
                }
            }
        }.start()
    }

    private fun request(permission: String, result: MethodChannel.Result) {
        val app = Uri.parse("package:$packageName")
        when (permission) {
            "notifications" -> {
                if (Build.VERSION.SDK_INT >= 33 &&
                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                ) {
                    val preferences = getPreferences(MODE_PRIVATE)
                    val asked = preferences.getBoolean("askedForNotifications", false)
                    if (!asked || shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)) {
                        preferences.edit().putBoolean("askedForNotifications", true).apply()
                        notificationReply = result
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1403)
                        return
                    }
                }
                val intent = if (PrayerAlarm.notificationAllowed(this)) {
                    channelSettings()
                } else {
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
                startActivity(intent)
            }
            "exact" -> if (Build.VERSION.SDK_INT >= 31 && !PrayerAlarm.exact(this)) {
                startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, app))
            }
            "fullScreen" -> {
                val intent = if (Build.VERSION.SDK_INT >= 34 && !PrayerAlarm.fullScreen(this)) {
                    Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, app)
                } else {
                    channelSettings()
                }
                startActivity(intent)
            }
        }
        result.success(null)
    }

    private fun channelSettings(): Intent =
        Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            .putExtra(Settings.EXTRA_CHANNEL_ID, PrayerAlarm.channelSettings(this))

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<String>, grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1403) {
            notificationReply?.success(null)
            notificationReply = null
        }
    }
}

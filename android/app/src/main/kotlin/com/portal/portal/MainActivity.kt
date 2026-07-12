package com.portal.portal

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.ActivityNotFoundException
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import android.content.ComponentName
import android.hardware.Sensor
import android.hardware.SensorManager
import android.net.wifi.WifiManager
import android.bluetooth.BluetoothAdapter
import android.nfc.NfcAdapter
import android.hardware.ConsumerIrManager
import android.telephony.TelephonyManager
import android.provider.AlarmClock

class MainActivity : FlutterActivity() {
    private val LAUNCHER_CHANNEL = "com.portal/launcher_setup"
    private val APPS_CHANNEL = "com.portal/apps"
    private var launcherChannel: MethodChannel? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.hasCategory(Intent.CATEGORY_HOME) || intent.action == Intent.ACTION_MAIN) {
            launcherChannel?.invokeMethod("onHomePressed", null)
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup launcher control channel
        launcherChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCHER_CHANNEL)
        launcherChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isDefaultHome" -> {
                    result.success(isDefaultHome())
                }
                "requestDefaultHome" -> {
                    requestDefaultHome()
                    result.success(true)
                }
                "getDeviceHardwareInfo" -> {
                    result.success(getDeviceHardwareInfo())
                }
                "isNotificationServiceEnabled" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "requestNotificationPermission" -> {
                    requestNotificationPermission()
                    result.success(true)
                }
                "getNotifications" -> {
                    result.success(getNotifications())
                }
                "dismissNotification" -> {
                    val key = call.argument<String>("key")
                    if (key != null) {
                        dismissNotification(key)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Key is null", null)
                    }
                }
                "openClockApp" -> {
                    result.success(openClockApp())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Setup apps channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APPS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    result.success(getInstalledApps())
                }
                "getAppIcon" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val iconBytes = getAppIcon(packageName)
                        result.success(iconBytes)
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is null", null)
                    }
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    val className = call.argument<String>("className")
                    if (packageName != null && className != null) {
                        launchApp(packageName, className)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Package or class name is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isDefaultHome(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            return roleManager.isRoleHeld(RoleManager.ROLE_HOME)
        }
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolveInfo = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        return resolveInfo?.activityInfo?.packageName == packageName
    }

    private fun requestDefaultHome() {
        // Try opening ACTION_HOME_SETTINGS first, as it is the most reliable way on Samsung/Android 9+ 
        // to take the user directly to the home app selector page.
        try {
            val intent = Intent(Settings.ACTION_HOME_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return
        } catch (e: Exception) {
            // Fallback to RoleManager on Q+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
                if (roleManager.isRoleAvailable(RoleManager.ROLE_HOME) &&
                    !roleManager.isRoleHeld(RoleManager.ROLE_HOME)) {
                    try {
                        val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        return
                    } catch (ex: Exception) {
                        // ignore and try next fallback
                    }
                }
            }
        }
        // General settings fallback
        try {
            val intent = Intent(Settings.ACTION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (e: Exception) {
            // No-op
        }
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = pm.queryIntentActivities(intent, 0)
        val apps = mutableListOf<Map<String, Any>>()
        for (resolveInfo in resolveInfos) {
            val appPackageName = resolveInfo.activityInfo.packageName
            if (appPackageName == packageName) continue

            val label = resolveInfo.loadLabel(pm).toString()
            val className = resolveInfo.activityInfo.name
            apps.add(mapOf(
                "label" to label,
                "packageName" to appPackageName,
                "className" to className
            ))
        }
        apps.sortBy { (it["label"] as String).lowercase() }
        return apps
    }

    private fun getAppIcon(packageName: String): ByteArray? {
        return try {
            val pm = packageManager
            val icon = pm.getApplicationIcon(packageName)
            val bitmap = if (icon is BitmapDrawable) {
                icon.bitmap
            } else {
                val width = icon.intrinsicWidth.coerceAtLeast(1)
                val height = icon.intrinsicHeight.coerceAtLeast(1)
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                icon.setBounds(0, 0, canvas.width, canvas.height)
                icon.draw(canvas)
                bitmap
            }
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            null
        }
    }

    private fun launchApp(packageName: String, className: String) {
        try {
            val intent = Intent().apply {
                setClassName(packageName, className)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback to standard launch intent if className fails
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            }
        }
    }

    private fun openClockApp(): Boolean {
        val clockPackages = arrayOf(
            "com.sec.android.app.clockpackage",
            "com.google.android.deskclock",
            "com.android.deskclock",
            "com.oneplus.deskclock",
            "com.xiaomi.misettings",
            "com.coloros.alarmclock"
        )
        for (pkg in clockPackages) {
            try {
                val intent = packageManager.getLaunchIntentForPackage(pkg)
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    return true
                }
            } catch (e: Exception) {}
        }
        try {
            val intent = Intent(AlarmClock.ACTION_SHOW_ALARMS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            return true
        } catch (e: Exception) {
            return false
        }
    }

    private fun getDeviceHardwareInfo(): Map<String, Any> {
        val info = mutableMapOf<String, Any>()
        
        // 1. Wifi
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        var wifiEnabled = false
        var wifiSsid = "Desconectado"
        var wifiRssi = 0
        var wifiSpeed = 0
        if (wifiManager != null) {
            wifiEnabled = wifiManager.isWifiEnabled
            if (wifiEnabled) {
                val connectionInfo = wifiManager.connectionInfo
                if (connectionInfo != null && connectionInfo.networkId != -1) {
                    wifiSsid = connectionInfo.ssid.replace("\"", "")
                    wifiRssi = connectionInfo.rssi
                    wifiSpeed = connectionInfo.linkSpeed
                }
            }
        }
        info["wifi"] = mapOf(
            "enabled" to wifiEnabled,
            "ssid" to wifiSsid,
            "rssi" to wifiRssi,
            "speed" to wifiSpeed
        )

        // 2. Bluetooth
        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        info["bluetooth"] = mapOf(
            "available" to (bluetoothAdapter != null),
            "enabled" to (bluetoothAdapter?.isEnabled ?: false),
            "state" to (if (bluetoothAdapter?.isEnabled == true) "ATIVO" else "INATIVO")
        )

        // 3. NFC
        val nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        info["nfc"] = mapOf(
            "available" to (nfcAdapter != null),
            "enabled" to (nfcAdapter?.isEnabled ?: false),
            "state" to (if (nfcAdapter != null) { if (nfcAdapter.isEnabled) "ATIVO" else "INATIVO" } else "NÃO DISPONÍVEL")
        )

        // 4. Infrared (IR)
        val irManager = getSystemService(Context.CONSUMER_IR_SERVICE) as? ConsumerIrManager
        val hasIr = irManager?.hasIrEmitter() ?: false
        info["infrared"] = mapOf(
            "available" to hasIr,
            "state" to (if (hasIr) "ATIVO" else "NÃO DISPONÍVEL")
        )

        // 5. Cellular Antenna (4G/LTE/5G)
        var cellularOperator = "Sem Sinal/Sem SIM"
        var cellularType = "Indisponível"
        var isSimReady = false
        try {
            val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            if (telephonyManager != null) {
                isSimReady = telephonyManager.simState == TelephonyManager.SIM_STATE_READY
                if (isSimReady) {
                    cellularOperator = telephonyManager.networkOperatorName ?: "Desconhecido"
                    val netType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        telephonyManager.dataNetworkType
                    } else {
                        telephonyManager.networkType
                    }
                    cellularType = when (netType) {
                        TelephonyManager.NETWORK_TYPE_LTE -> "4G (LTE)"
                        TelephonyManager.NETWORK_TYPE_NR -> "5G"
                        TelephonyManager.NETWORK_TYPE_HSDPA, TelephonyManager.NETWORK_TYPE_HSPAP, TelephonyManager.NETWORK_TYPE_HSUPA -> "3G"
                        TelephonyManager.NETWORK_TYPE_GPRS, TelephonyManager.NETWORK_TYPE_EDGE -> "2G"
                        else -> "Celular/4G"
                    }
                }
            }
        } catch (e: Exception) {}

        info["cellular"] = mapOf(
            "available" to isSimReady,
            "operator" to cellularOperator,
            "type" to cellularType,
            "state" to (if (isSimReady) "ATIVO" else "NÃO DETECTADO")
        )

        // 6. FM Radio Receiver
        val fmPackages = arrayOf(
            "com.sec.android.app.fm", 
            "com.mediatek.fmradio", 
            "com.android.fmradio", 
            "com.caf.fmradio"
        )
        var hasFm = false
        for (pkg in fmPackages) {
            try {
                packageManager.getPackageInfo(pkg, 0)
                hasFm = true
                break
            } catch (e: Exception) {}
        }
        // Samsung A15 has physical FM radio hardware
        if (Build.MODEL.contains("A15") || Build.DEVICE.contains("A15")) {
            hasFm = true
        }
        info["radio"] = mapOf(
            "available" to hasFm,
            "state" to (if (hasFm) "DISPONÍVEL (requer fone)" else "NÃO SUPORTADO")
        )

        // 7. Sensors list
        val sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val sensorList = sensorManager?.getSensorList(Sensor.TYPE_ALL) ?: emptyList()
        val sensors = sensorList.map { sensor ->
            mapOf(
                "name" to sensor.name,
                "vendor" to sensor.vendor,
                "version" to sensor.version,
                "power" to sensor.power.toDouble(),
                "type" to sensor.stringType
            )
        }
        info["sensors"] = sensors

        return info
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val cn = ComponentName(this, MyNotificationListenerService::class.java)
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(cn.flattenToString())
    }

    private fun requestNotificationPermission() {
        try {
            startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
        } catch (e: Exception) {
            // fallback
        }
    }

    private fun getNotifications(): List<Map<String, String>> {
        MyNotificationListenerService.instance?.updateNotifications()
        return MyNotificationListenerService.activeNotificationsList
    }

    private fun dismissNotification(key: String) {
        MyNotificationListenerService.instance?.cancelNotification(key)
    }
}

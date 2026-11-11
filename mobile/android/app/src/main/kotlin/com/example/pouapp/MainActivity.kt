package com.example.pouapp

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val whatsAppShareChannel = "com.pouapp.app/whatsapp_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            whatsAppShareChannel,
        ).setMethodCallHandler { call, result ->
            if (call.method != "sharePdf") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            val digits = call.argument<String>("digits")
            if (path.isNullOrBlank() || digits.isNullOrBlank()) {
                result.error("bad_args", "path and digits are required", null)
                return@setMethodCallHandler
            }
            try {
                result.success(sharePdfToWhatsApp(path, digits))
            } catch (error: Exception) {
                result.error("share_failed", error.message, null)
            }
        }
    }

    private fun sharePdfToWhatsApp(path: String, digits: String): Boolean {
        val file = File(path)
        if (!file.exists()) return false

        val packageName =
            listOf("com.whatsapp", "com.whatsapp.w4b").firstOrNull { isInstalled(it) }
                ?: return false

        val uri =
            FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file,
            )
        grantUriPermission(
            packageName,
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION,
        )
        val jid = "${digits.filter { it.isDigit() }}@s.whatsapp.net"
        val intent =
            Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                setPackage(packageName)
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TEXT, "Segue a nota em PDF.")
                putExtra("jid", jid)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                clipData = android.content.ClipData.newUri(contentResolver, "nota", uri)
            }
        startActivity(intent)
        return true
    }

    private fun isInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }
}

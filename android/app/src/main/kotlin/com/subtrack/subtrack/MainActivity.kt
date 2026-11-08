package com.subtrack.subtrack

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "subtrack/editor",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openForEdit") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val path = call.argument<String>("path")
            val mimeType = call.argument<String>("mimeType") ?: "*/*"
            if (path == null) {
                result.error("bad_args", "Missing file path.", null)
                return@setMethodCallHandler
            }

            val file = File(path)
            if (!file.exists()) {
                result.error(
                    "missing_file",
                    "The working copy no longer exists.",
                    null,
                )
                return@setMethodCallHandler
            }

            try {
                val uri = FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    file,
                )
                val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                val intent = Intent(Intent.ACTION_EDIT).apply {
                    setDataAndType(uri, mimeType)
                    clipData = ClipData.newRawUri("working copy", uri)
                    addFlags(flags)
                }

                // Some editors (notably Word) move the URI into their own
                // activity/process and lose the one-shot intent grant. Grant
                // the package explicitly so saving back to the original file
                // is allowed for the whole editing session.
                for (handler in packageManager.queryIntentActivities(intent, 0)) {
                    grantUriPermission(
                        handler.activityInfo.packageName,
                        uri,
                        flags,
                    )
                }

                startActivity(intent)
                result.success(true)
            } catch (e: ActivityNotFoundException) {
                result.error("no_editor", "No app can edit this file.", null)
            } catch (e: Exception) {
                result.error("open_failed", e.message, null)
            }
        }
    }
}

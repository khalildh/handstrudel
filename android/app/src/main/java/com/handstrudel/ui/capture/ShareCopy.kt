package com.handstrudel.ui.capture

import android.content.ClipData
import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.FileProvider
import com.handstrudel.capture.drafts.DraftExport
import java.io.File

/**
 * Shares a temporary copy through the Android share sheet (iOS `ShareSheet`).
 *
 * iOS deletes the copy when the share sheet disappears, by which point the target has the
 * file. Android's chooser returns as soon as a target is picked, while the target may still
 * be reading the `content://` URI, so the copy is left in `cacheDir/exports` and removed by
 * [DraftExport.sweep] once it's an hour old (before each share and at launch).
 */
class ShareCopyLauncher internal constructor(private val launch: (File, String) -> Unit) {
    fun share(file: File, mimeType: String) = launch(file, mimeType)
}

@Composable
fun rememberShareCopyLauncher(): ShareCopyLauncher {
    val context = LocalContext.current
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { }
    return remember(launcher) {
        ShareCopyLauncher { file, mime ->
            runCatching { DraftExport.sweep(context) }
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            val send = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                clipData = ClipData.newRawUri(null, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            launcher.launch(Intent.createChooser(send, null))
        }
    }
}

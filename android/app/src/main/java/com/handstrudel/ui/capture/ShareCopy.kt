package com.handstrudel.ui.capture

import android.content.ClipData
import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.FileProvider
import java.io.File

/**
 * Shares a temporary copy through the Android share sheet and deletes it when the
 * user comes back (iOS `ShareSheet` + `.onDisappear { copy.remove() }`).
 */
class ShareCopyLauncher internal constructor(private val launch: (File, String) -> Unit) {
    fun share(file: File, mimeType: String) = launch(file, mimeType)
}

@Composable
fun rememberShareCopyLauncher(): ShareCopyLauncher {
    val context = LocalContext.current
    val pending = remember { arrayOfNulls<File>(1) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) {
        pending[0]?.delete()
        pending[0] = null
    }
    return remember(launcher) {
        ShareCopyLauncher { file, mime ->
            pending[0]?.delete()
            pending[0] = file
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

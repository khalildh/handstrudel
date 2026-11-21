package com.handstrudel.app

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri

/**
 * Shared "share a file" helper (iOS `ShareSheet`). Owner: shell. [uri] must be a
 * `content://` Uri from the app's FileProvider (`${applicationId}.fileprovider`).
 */
fun shareFile(context: Context, uri: Uri, mimeType: String, chooserTitle: String? = null) {
    val send = Intent(Intent.ACTION_SEND).apply {
        type = mimeType
        putExtra(Intent.EXTRA_STREAM, uri)
        clipData = ClipData.newRawUri(null, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(Intent.createChooser(send, chooserTitle).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}

/** Shares plain text (e.g. a watch URL). */
fun shareText(context: Context, text: String, chooserTitle: String? = null) {
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, text)
    }
    context.startActivity(Intent.createChooser(send, chooserTitle).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}

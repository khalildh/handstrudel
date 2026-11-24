package com.handstrudel.app

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log

/**
 * Shared "share a file" helper (iOS `ShareSheet`). Owner: shell. [uri] must be a
 * `content://` Uri from the app's FileProvider (`${applicationId}.fileprovider`).
 * Returns false when no app can receive it.
 */
fun shareFile(context: Context, uri: Uri, mimeType: String, chooserTitle: String? = null): Boolean {
    val send = Intent(Intent.ACTION_SEND).apply {
        type = mimeType
        putExtra(Intent.EXTRA_STREAM, uri)
        clipData = ClipData.newRawUri(null, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    return startChooser(context, send, chooserTitle)
}

/** Shares plain text (e.g. a watch URL). Returns false when no app can receive it. */
fun shareText(context: Context, text: String, chooserTitle: String? = null): Boolean {
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, text)
    }
    return startChooser(context, send, chooserTitle)
}

private fun startChooser(context: Context, send: Intent, chooserTitle: String?): Boolean = try {
    val chooser = Intent.createChooser(send, chooserTitle)
    if (context !is android.app.Activity) chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    context.startActivity(chooser)
    true
} catch (e: ActivityNotFoundException) {
    Log.i("Share", "no share target: ${e.javaClass.simpleName}")
    false
}

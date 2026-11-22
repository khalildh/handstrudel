package com.handstrudel.ui.social.account

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ImageDecoder
import android.graphics.Paint
import android.graphics.Rect
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AccountCircle
import androidx.compose.material.icons.outlined.Photo
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.social.AuthManager
import com.handstrudel.social.SocialConfig
import com.handstrudel.social.data.ProfileImageStore
import com.handstrudel.ui.social.ProfileImage
import com.handstrudel.ui.social.SocialScreen
import com.handstrudel.ui.social.rememberSocial
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

/**
 * iOS `AvatarPhoto.jpeg`: centred square crop, at most 512 px, on white, JPEG q0.84,
 * rejected over 384 KiB. ImageDecoder applies EXIF orientation.
 */
object AvatarPhoto {
    fun jpeg(context: Context, uri: Uri): ByteArray? = runCatching {
        val source = ImageDecoder.createSource(context.contentResolver, uri)
        val decoded = ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
            val longest = maxOf(info.size.width, info.size.height)
            if (longest > 1024) {
                val scale = 1024f / longest
                decoder.setTargetSize((info.size.width * scale).toInt().coerceAtLeast(1), (info.size.height * scale).toInt().coerceAtLeast(1))
            }
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
        }
        jpeg(decoded)
    }.getOrNull()

    fun jpeg(image: Bitmap): ByteArray? {
        val side = minOf(image.width, image.height)
        if (side <= 0) return null
        val out = minOf(side, 512)
        val bitmap = Bitmap.createBitmap(out, out, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(android.graphics.Color.WHITE)
        val crop = Rect((image.width - side) / 2, (image.height - side) / 2, (image.width - side) / 2 + side, (image.height - side) / 2 + side)
        canvas.drawBitmap(image, crop, Rect(0, 0, out, out), Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG))
        val bytes = ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.JPEG, 84, it) }.toByteArray()
        return bytes.takeIf { it.size <= 384 * 1024 }
    }
}

/** iOS `EditCreatorProfileView`: photo (choose/remove, uploaded on Save) and display name (≤ 40). */
@Composable
fun EditProfileSheet(onDismiss: () -> Unit) {
    val social = rememberSocial() ?: return
    val auth = social.auth
    val p = LocalStudioPalette.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val profile by auth.profile.collectAsState()
    var name by remember { mutableStateOf(profile?.displayName ?: "") }
    var saving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var pendingPhoto by remember { mutableStateOf<ByteArray?>(null) }
    var removePhoto by remember { mutableStateOf(false) }
    var loadingPhoto by remember { mutableStateOf(false) }
    var confirmingRemoval by remember { mutableStateOf(false) }
    var selection by remember { mutableStateOf<Uri?>(null) }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri -> if (uri != null) selection = uri }

    LaunchedEffect(selection) {
        val uri = selection ?: run { loadingPhoto = false; return@LaunchedEffect }
        loadingPhoto = true
        error = null
        val jpeg = withContext(Dispatchers.Default) { AvatarPhoto.jpeg(context, uri) }
        loadingPhoto = false
        if (jpeg != null) { pendingPhoto = jpeg; removePhoto = false } else {
            selection = null
            error = "Couldn't open that image. Choose another photo and try again."
        }
    }

    fun save() {
        saving = true
        error = null
        scope.launch {
            try {
                if (name.trim() != (auth.profile.value?.displayName ?: "")) {
                    try { auth.updateDisplayName(name) } catch (e: Exception) { error = "Couldn't save your display name. Try again."; return@launch }
                }
                if (pendingPhoto != null || removePhoto) {
                    try {
                        auth.updateAvatar(pendingPhoto)
                    } catch (e: AuthManager.FunctionHttpException) {
                        error = if (e.status == 429) "Wait a few seconds before uploading another photo." else "Couldn't update your profile photo. Try again."
                        return@launch
                    } catch (e: Exception) {
                        error = "Couldn't update your profile photo. Try again."
                        return@launch
                    }
                }
                onDismiss()
            } finally { saving = false }
        }
    }

    val tooLong = name.trim().let { it.codePointCount(0, it.length) } > AuthManager.DISPLAY_NAME_LIMIT
    SocialScreen("Edit profile", onDismiss, dismissLabel = "Cancel", dismissOnLeading = true, dismissEnabled = !saving, trailing = {
        TextButton(onClick = ::save, enabled = !saving && !loadingPhoto && !tooLong, modifier = Modifier.testTag("profile-save")) {
            Text("Save", color = p.accent, fontWeight = FontWeight.SemiBold)
        }
    }) {
        Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("PROFILE PHOTO", color = p.muted, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Box(Modifier.size(58.dp).clip(CircleShape).background(p.surface), contentAlignment = Alignment.Center) {
                    Icon(Icons.Outlined.AccountCircle, null, tint = p.muted)
                    val pending = pendingPhoto
                    val key = profile?.avatarKey
                    if (pending != null) {
                        val bitmap = remember(pending) { android.graphics.BitmapFactory.decodeByteArray(pending, 0, pending.size)?.asImageBitmap() }
                        if (bitmap != null) Image(bitmap, null, contentScale = ContentScale.Crop, modifier = Modifier.size(58.dp))
                    } else if (!removePhoto && key != null) {
                        ProfileImage(ProfileImageStore.Resource(SocialConfig.mediaUrl(key), ProfileImageStore.Kind.AVATAR), Modifier.size(58.dp))
                    }
                }
                TextButton(onClick = { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }, enabled = !saving,
                    modifier = Modifier.testTag("profile-choose-photo")) {
                    Icon(Icons.Outlined.Photo, null, tint = p.accent); Text("  Choose photo", color = p.accent)
                }
                if (loadingPhoto) CircularProgressIndicator(color = p.accent, modifier = Modifier.size(18.dp))
            }
            if (pendingPhoto != null || (!removePhoto && profile?.avatarKey != null)) {
                TextButton(onClick = {
                    if (pendingPhoto != null && profile?.avatarKey == null) { pendingPhoto = null; selection = null } else confirmingRemoval = true
                }, enabled = !saving) { Text("Remove photo", color = p.recording) }
            }
            Text("Your photo is public. Only the selected image is uploaded, after you tap Save.", color = p.muted, fontSize = 13.sp)
            OutlinedTextField(value = name, onValueChange = { name = it }, singleLine = true, enabled = !saving,
                placeholder = { Text("Display name") }, modifier = Modifier.fillMaxWidth().padding(top = 12.dp).testTag("profile-display-name"))
            Text("Leave blank to show your username instead.", color = p.muted, fontSize = 13.sp)
            error?.let { Text(it, color = p.muted, modifier = Modifier.testTag("profile-edit-error")) }
        }
    }
    if (confirmingRemoval) {
        AlertDialog(onDismissRequest = { confirmingRemoval = false }, title = { Text("Remove your profile photo?") },
            confirmButton = {
                TextButton(onClick = { confirmingRemoval = false; selection = null; pendingPhoto = null; removePhoto = true },
                    modifier = Modifier.testTag("profile-confirm-remove-photo")) { Text("Remove photo", color = p.recording) }
            },
            dismissButton = { TextButton(onClick = { confirmingRemoval = false }) { Text("Cancel") } })
    }
}

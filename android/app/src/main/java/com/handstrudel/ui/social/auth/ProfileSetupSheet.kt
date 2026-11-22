package com.handstrudel.ui.social.auth
import com.handstrudel.ui.theme.IosSwitch

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.ClickableText
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.social.AuthManager
import com.handstrudel.social.SocialConfig
import com.handstrudel.social.model.Profile
import com.handstrudel.ui.social.ProfileActionButton
import com.handstrudel.ui.social.openUrl
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.launch

/** iOS `ProfileSetupView`: username + terms acceptance (required before posting). */
@Composable
fun ProfileSetupForm(auth: AuthManager) {
    val p = LocalStudioPalette.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var username by rememberSaveable { mutableStateOf("") }
    var agreed by rememberSaveable { mutableStateOf(false) }
    var busy by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(Unit) { if (username.isEmpty()) username = auth.profile.value?.username ?: "" }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("CHOOSE A USERNAME", color = p.muted, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        OutlinedTextField(
            value = username, onValueChange = { username = Profile.normalizeUsername(it) },
            placeholder = { Text("username") }, singleLine = true,
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None, autoCorrectEnabled = false),
            modifier = Modifier.fillMaxWidth().testTag("profile-username"),
        )
        Text("3–20 characters: lowercase letters, numbers and _", color = p.muted, fontSize = 13.sp)
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
            val text = buildAnnotatedString {
                append("I agree to the ")
                pushStringAnnotation("url", SocialConfig.TERMS_URL)
                withStyle(SpanStyle(color = p.accent, textDecoration = TextDecoration.Underline)) { append("Terms") }
                pop()
                append(" and ")
                pushStringAnnotation("url", SocialConfig.GUIDELINES_URL)
                withStyle(SpanStyle(color = p.accent, textDecoration = TextDecoration.Underline)) { append("Community Guidelines") }
                pop()
                append(". No objectionable content or abusive behavior.")
            }
            @Suppress("DEPRECATION")
            ClickableText(
                text, style = androidx.compose.ui.text.TextStyle(color = p.ink, fontSize = 13.sp),
                modifier = Modifier.weight(1f),
            ) { offset ->
                text.getStringAnnotations("url", offset, offset).firstOrNull()?.let { openUrl(context, it.item) } ?: run { agreed = !agreed }
            }
            IosSwitch(checked = agreed, onCheckedChange = { agreed = it }, modifier = Modifier.testTag("profile-agree"), tint = p.accent)
        }
        ProfileActionButton(
            "Continue", primary = true, enabled = Profile.isValidUsername(username) && agreed && !busy,
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp).testTag("profile-continue"),
            onClick = { scope.launch { busy = true; auth.completeProfile(username); busy = false } },
        )
    }
}

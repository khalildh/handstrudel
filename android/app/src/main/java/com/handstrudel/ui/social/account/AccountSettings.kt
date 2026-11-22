package com.handstrudel.ui.social.account

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.HelpOutline
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Palette
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.AppAnalyticsEvent
import com.handstrudel.app.LocalAppServices
import com.handstrudel.social.SocialConfig
import com.handstrudel.ui.social.SocialMaterialTheme
import com.handstrudel.ui.social.SocialScreen
import com.handstrudel.ui.social.openPlayListing
import com.handstrudel.ui.social.openUrl
import com.handstrudel.ui.theme.LocalStudioPalette

/** Which account sheet the gear menu opened. */
enum class AccountSheet { APPEARANCE, USAGE_ANALYTICS, BLOCKED, DELETE_ACCOUNT }

/**
 * iOS `ProfileView.header` menu: Appearance, Usage Analytics, (signed in) Blocked users,
 * Sign out, Delete account…, Community Guidelines, Terms of Use, Write a review, Get help.
 */
@Composable
fun AccountSettingsMenu(signedIn: Boolean, onOpen: (AccountSheet) -> Unit, onSignOut: () -> Unit) {
    val p = LocalStudioPalette.current
    val context = LocalContext.current
    var open by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { open = true }, modifier = Modifier.semantics { contentDescription = "Account settings" }.testTag("account-settings")) {
            Box(Modifier.size(44.dp).clip(CircleShape).background(p.surface).border(1.dp, p.border, CircleShape), contentAlignment = Alignment.Center) {
                Icon(Icons.Outlined.Settings, null, tint = p.ink)
            }
        }
        SocialMaterialTheme {
            DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
                fun go(action: () -> Unit) { open = false; action() }
                DropdownMenuItem(text = { Text("Appearance") }, leadingIcon = { Icon(Icons.Outlined.Palette, null) }, onClick = { go { onOpen(AccountSheet.APPEARANCE) } })
                DropdownMenuItem(text = { Text("Usage Analytics") }, leadingIcon = { Icon(Icons.Outlined.BarChart, null) }, onClick = { go { onOpen(AccountSheet.USAGE_ANALYTICS) } })
                if (signedIn) {
                    DropdownMenuItem(text = { Text("Blocked users") }, onClick = { go { onOpen(AccountSheet.BLOCKED) } }, modifier = Modifier.testTag("menu-blocked-users"))
                    DropdownMenuItem(text = { Text("Sign out") }, onClick = { go(onSignOut) }, modifier = Modifier.testTag("menu-sign-out"))
                    DropdownMenuItem(text = { Text("Delete account…", color = p.recording) }, onClick = { go { onOpen(AccountSheet.DELETE_ACCOUNT) } },
                        modifier = Modifier.testTag("menu-delete-account"))
                }
                DropdownMenuItem(text = { Text("Community Guidelines") }, onClick = { go { openUrl(context, SocialConfig.GUIDELINES_URL) } })
                DropdownMenuItem(text = { Text("Terms of Use") }, onClick = { go { openUrl(context, SocialConfig.TERMS_URL) } })
                HorizontalDivider()
                DropdownMenuItem(text = { Text("Write a review") }, leadingIcon = { Icon(Icons.Outlined.StarOutline, null) }, onClick = { go { openPlayListing(context) } })
                DropdownMenuItem(text = { Text("Get help") }, leadingIcon = { Icon(Icons.AutoMirrored.Outlined.HelpOutline, null) }, onClick = { go { openUrl(context, SocialConfig.SUPPORT_URL) } })
            }
        }
    }
}


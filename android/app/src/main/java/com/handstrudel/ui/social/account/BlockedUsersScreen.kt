package com.handstrudel.ui.social.account

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.handstrudel.social.data.FeedService
import com.handstrudel.ui.social.SocialScreen
import com.handstrudel.ui.social.rememberSocial
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.launch

/** iOS `BlockedUsersView`: people you've blocked, with Unblock. */
@Composable
fun BlockedUsersScreen(onDismiss: () -> Unit) {
    val social = rememberSocial() ?: return
    val p = LocalStudioPalette.current
    val scope = rememberCoroutineScope()
    var blocked by remember { mutableStateOf<List<FeedService.BlockedUser>>(emptyList()) }
    var loaded by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        social.auth.userId.value?.let { uid -> blocked = runCatching { social.feed.blockedUsers(uid) }.getOrDefault(emptyList()) }
        loaded = true
    }
    SocialScreen("Blocked users", onDismiss) {
        LazyColumn(Modifier.weight(1f).fillMaxWidth()) {
            if (loaded && blocked.isEmpty()) item { Text("You haven't blocked anyone.", color = p.muted, modifier = Modifier.padding(20.dp)) }
            items(blocked, key = { it.blockedId }) { b ->
                Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("@${b.profile?.username ?: "user"}", color = p.ink, modifier = Modifier.weight(1f))
                    OutlinedButton(onClick = {
                        val uid = social.auth.userId.value ?: return@OutlinedButton
                        scope.launch {
                            runCatching { social.feed.unblock(b.blockedId, uid) }
                            blocked = blocked.filter { it.blockedId != b.blockedId }
                        }
                    }, modifier = Modifier.testTag("unblock")) { Text("Unblock", color = p.accent) }
                }
            }
        }
    }
}

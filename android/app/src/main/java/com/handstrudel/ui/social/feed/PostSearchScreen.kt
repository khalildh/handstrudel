package com.handstrudel.ui.social.feed

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.social.data.FeedService
import com.handstrudel.social.model.PostSearch
import com.handstrudel.social.model.Video
import com.handstrudel.ui.social.SocialScreen
import com.handstrudel.ui.social.rememberSocial
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.UUID

/** iOS `PostSearchView`: debounced caption/instrument/creator search; `@handle` scopes to usernames. */
@Composable
fun PostSearchScreen(onDismiss: () -> Unit, onStart: (PerformanceStart) -> Unit) {
    val social = rememberSocial() ?: return
    val p = LocalStudioPalette.current
    val scope = rememberCoroutineScope()
    val userId by social.auth.userId.collectAsState()
    var input by remember { mutableStateOf("") }
    var requestId by remember { mutableStateOf(UUID.randomUUID()) }
    var results by remember { mutableStateOf<List<Video>>(emptyList()) }
    var cursor by remember { mutableStateOf<Video?>(null) }
    var busy by remember { mutableStateOf(false) }
    var more by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    var opened by remember { mutableStateOf<Video?>(null) }
    val search = PostSearch.parse(input)

    fun reset() {
        results = emptyList(); cursor = null; more = false; failed = false
        busy = PostSearch.parse(input) != null
        requestId = UUID.randomUUID()
    }

    suspend fun load(search: PostSearch, id: UUID, after: Video?) {
        if (requestId != id) return
        failed = false
        try {
            val page = social.feed.page(after = after, search = search)
            if (requestId != id) return
            val loaded = results.map { it.id }.toSet()
            results = results + page.filter { it.id !in loaded }
            cursor = page.lastOrNull() ?: after
            more = page.size == FeedService.PAGE_SIZE
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            if (requestId == id) failed = true
        } finally {
            if (requestId == id) busy = false
        }
    }

    fun loadNextPage() {
        val s = PostSearch.parse(input) ?: return
        if (busy) return
        busy = true
        val id = requestId
        val after = cursor
        scope.launch { load(s, id, after) }
    }

    LaunchedEffect(userId) { reset() }
    LaunchedEffect(requestId) {
        val id = requestId
        val s = PostSearch.parse(input) ?: return@LaunchedEffect
        delay(300)
        load(s, id, null)
    }

    SocialScreen("Search posts", onDismiss) {
        OutlinedTextField(
            value = input, onValueChange = { input = it; reset() }, singleLine = true,
            placeholder = { Text("Caption, instrument, or creator") },
            leadingIcon = { Icon(Icons.Filled.Search, null) },
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp).testTag("search-field"),
        )
        LazyColumn(Modifier.weight(1f).fillMaxWidth()) {
            if (search == null) {
                item { Text("Enter at least two characters. Use @ to search posts by creator handle.", color = p.muted, modifier = Modifier.padding(20.dp)) }
            } else if (results.isEmpty() && !busy && !failed) {
                item {
                    val broader = search.broaderInput
                    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(if (search.isHandleSearch) "No posts match that handle" else "No matching posts", color = p.ink, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
                        Text(
                            when {
                                broader != null -> "Check the handle, or also search captions, instruments, and creator names."
                                search.isHandleSearch -> "Check the spelling or try a different handle."
                                else -> "Try a shorter search, a different instrument, or a creator's name."
                            }, color = p.muted,
                        )
                        if (broader != null) TextButton(onClick = { input = broader; reset() }) { Text("Broaden search", color = p.accent) }
                    }
                }
            }
            items(results, key = { it.id }) { video -> PerformanceListRow(video, onClick = { opened = video }) }
            if (busy) item { Column(Modifier.fillMaxWidth().padding(20.dp)) { CircularProgressIndicator(color = p.accent); Text("Searching posts", color = p.muted) } }
            if (failed) {
                item {
                    Column(Modifier.padding(20.dp)) {
                        Text(if (cursor == null) "Couldn't load search results." else "Couldn't load more results.", color = p.muted)
                        TextButton(onClick = ::loadNextPage) { Text("Try again", color = p.accent) }
                    }
                }
            } else if (more && !busy) {
                item { TextButton(onClick = ::loadNextPage, modifier = Modifier.padding(horizontal = 12.dp)) { Text("Load more", color = p.accent) } }
            }
        }
    }
    opened?.let { video ->
        CreatorVideoSheet(video, onDismiss = { opened = null },
            onPlayAlong = { opened = null; onStart(PerformanceStart.Backing(it)) },
            onTrySound = { opened = null; onStart(PerformanceStart.Preset(it)) })
    }
}

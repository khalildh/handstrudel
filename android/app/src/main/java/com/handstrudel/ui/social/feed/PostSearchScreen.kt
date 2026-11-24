package com.handstrudel.ui.social.feed

import androidx.compose.material.icons.filled.Cancel
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.itemsIndexed
import com.handstrudel.ui.theme.iosLight
import com.handstrudel.ui.theme.IosGrouped
import com.handstrudel.ui.theme.GroupedCell
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
import androidx.compose.ui.Alignment
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

    // iOS: `.searchable` (navigation-bar drawer field) over a default inset grouped `List`.
    val light = iosLight()
    val secondary = IosGrouped.secondaryLabel(light)
    val rowPad = Modifier.padding(horizontal = IosGrouped.CellInset, vertical = 11.dp)
    SocialScreen("Search posts", onDismiss, background = IosGrouped.background(light)) {
        BasicTextField(
            value = input, onValueChange = { input = it; reset() }, singleLine = true,
            textStyle = androidx.compose.ui.text.TextStyle(color = p.ink, fontSize = 17.sp),
            cursorBrush = SolidColor(p.accent),
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp).testTag("search-field"),
            decorationBox = { inner ->
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 36.dp).clip(RoundedCornerShape(10.dp)).background(IosGrouped.searchFill(light))
                        .padding(start = 8.dp, end = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.Search, null, tint = secondary, modifier = Modifier.size(22.dp))
                    Spacer(Modifier.width(6.dp))
                    Box(Modifier.weight(1f)) {
                        if (input.isEmpty()) Text("Caption, instrument, or creator", color = secondary, fontSize = 17.sp, maxLines = 1)
                        inner()
                    }
                    if (input.isNotEmpty()) {
                        Icon(Icons.Filled.Cancel, "Clear text", tint = secondary,
                            modifier = Modifier.size(20.dp).clickable { input = ""; reset() })
                    }
                }
            },
        )
        val rows = buildList<@Composable () -> Unit> {
            if (search == null) {
                add { Text("Enter at least two characters. Use @ to search posts by creator handle.", color = secondary, fontSize = 17.sp, modifier = rowPad) }
            } else if (results.isEmpty() && !busy && !failed) {
                add {
                    val broader = search.broaderInput
                    Column(rowPad, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(if (search.isHandleSearch) "No posts match that handle" else "No matching posts", color = p.ink, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
                        Text(
                            when {
                                broader != null -> "Check the handle, or also search captions, instruments, and creator names."
                                search.isHandleSearch -> "Check the spelling or try a different handle."
                                else -> "Try a shorter search, a different instrument, or a creator's name."
                            }, color = secondary,
                        )
                        if (broader != null) TextButton(onClick = { input = broader; reset() }) { Text("Broaden search", color = p.accent) }
                    }
                }
            }
            results.forEach { video -> add { PerformanceListRow(video, onClick = { opened = video }) } }
            if (busy) add { Column(rowPad.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) { CircularProgressIndicator(color = p.accent); Text("Searching posts", color = secondary) } }
            if (failed) {
                add { Text(if (cursor == null) "Couldn't load search results." else "Couldn't load more results.", color = secondary, fontSize = 17.sp, modifier = rowPad) }
                add { Text("Try again", color = p.accent, fontSize = 17.sp, modifier = Modifier.fillMaxWidth().clickable(onClick = ::loadNextPage).then(rowPad)) }
            } else if (more && !busy) {
                add { Text("Load more", color = p.accent, fontSize = 17.sp, modifier = Modifier.fillMaxWidth().clickable(onClick = ::loadNextPage).then(rowPad)) }
            }
        }
        LazyColumn(Modifier.weight(1f).fillMaxWidth(), contentPadding = PaddingValues(top = 24.dp, bottom = 24.dp)) {
            itemsIndexed(rows) { i, row -> GroupedCell(i, rows.size) { row() } }
        }
    }
    opened?.let { video ->
        CreatorVideoSheet(video, onDismiss = { opened = null },
            onPlayAlong = { opened = null; onStart(PerformanceStart.Backing(it)) },
            onTrySound = { opened = null; onStart(PerformanceStart.Preset(it)) })
    }
}

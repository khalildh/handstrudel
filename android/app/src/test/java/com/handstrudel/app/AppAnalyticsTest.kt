package com.handstrudel.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Ports iOS `AppAnalytics` rules with fake prefs, store and clock. */
class AppAnalyticsTest {
    private val dayMs = 86_400_000L
    private val store = InMemoryPrefsStore()
    private val prefs = StoreBackedAppPrefs(store)
    private val sent = mutableListOf<String>()
    private var clock = 20_000 * dayMs + 3_600_000L

    private fun analytics(enabled: Boolean = true) =
        DefaultAppAnalytics(prefs, store, enabled = enabled, nowMillis = { clock }) { sent += it.raw }

    @Test fun defaultIsOff() {
        assertFalse(prefs.appUsageAnalyticsEnabled.value)
        assertFalse(analytics().isEnabled.value)
    }

    @Test fun optedOutSendsNothing() {
        val a = analytics()
        a.recordActiveDay()
        AppAnalyticsEvent.entries.forEach(a::record)
        assertTrue(sent.isEmpty())
        assertEquals(null, store.getString(DefaultAppAnalytics.LAST_ACTIVE_DAY_KEY))
    }

    @Test fun turningOnRecordsActiveDayOnce() {
        val a = analytics()
        a.setEnabled(true)
        assertEquals(listOf("active_day"), sent)
        a.setEnabled(true)
        a.recordActiveDay()
        a.record(AppAnalyticsEvent.ACTIVE_DAY)
        assertEquals(listOf("active_day"), sent)
        assertEquals("20000", store.getString(DefaultAppAnalytics.LAST_ACTIVE_DAY_KEY))
    }

    @Test fun activeDayIsPerUtcDayAndReturnDayFollows() {
        val a = analytics()
        prefs.setAppUsageAnalyticsEnabled(true)
        a.recordActiveDay()
        clock += dayMs - 3_600_001L // 23:59:59.999 UTC, same day
        a.recordActiveDay()
        assertEquals(listOf("active_day"), sent)
        clock += 1 // next UTC day
        a.recordActiveDay()
        assertEquals(listOf("active_day", "active_day", "return_day"), sent)
        clock -= 5 * dayMs // clock moved back: never re-sends an older day
        a.recordActiveDay()
        assertEquals(3, sent.size)
    }

    @Test fun returnDayIsNeverSentDirectly() {
        prefs.setAppUsageAnalyticsEnabled(true)
        analytics().record(AppAnalyticsEvent.RETURN_DAY)
        assertTrue(sent.isEmpty())
    }

    @Test fun firstNoteOncePerInstall() {
        prefs.setAppUsageAnalyticsEnabled(true)
        analytics().record(AppAnalyticsEvent.FIRST_NOTE)
        analytics().record(AppAnalyticsEvent.FIRST_NOTE)
        assertEquals(listOf("first_note"), sent)
    }

    @Test fun firstNoteWhileOptedOutDoesNotUseUpTheOnce() {
        val a = analytics()
        a.record(AppAnalyticsEvent.FIRST_NOTE)
        prefs.setAppUsageAnalyticsEnabled(true)
        a.record(AppAnalyticsEvent.FIRST_NOTE)
        assertEquals(listOf("first_note"), sent)
    }

    @Test fun recordingEventsAreSentEachTime() {
        prefs.setAppUsageAnalyticsEnabled(true)
        val a = analytics()
        repeat(2) {
            a.record(AppAnalyticsEvent.RECORDING_STARTED)
            a.record(AppAnalyticsEvent.RECORDING_SAVED)
            a.record(AppAnalyticsEvent.RECORDING_POSTED)
        }
        assertEquals(
            listOf("recording_started", "recording_saved", "recording_posted", "recording_started", "recording_saved", "recording_posted"),
            sent,
        )
    }

    @Test fun disabledInstanceSendsNothingEvenWhenOptedIn() {
        prefs.setAppUsageAnalyticsEnabled(true)
        val a = analytics(enabled = false)
        a.recordActiveDay()
        a.record(AppAnalyticsEvent.RECORDING_SAVED)
        assertTrue(sent.isEmpty())
    }

    @Test fun payloadAndConfiguration() {
        assertEquals("""{"p_event":"active_day"}""", UsageEventSender.payload(AppAnalyticsEvent.ACTIVE_DAY))
        assertFalse(UsageEventSender.isBackendConfigured("", "key"))
        assertFalse(UsageEventSender.isBackendConfigured("https://x.supabase.co", ""))
        assertFalse(UsageEventSender.isBackendConfigured("https://x.supabase.co", "YOUR-ANON-KEY"))
        assertTrue(UsageEventSender.isBackendConfigured("https://x.supabase.co", "sb_publishable_x"))
    }

    @Test fun unconfiguredSenderNeverLaunches() {
        // Would throw on the JVM (android.util.Log / network) if it tried to send.
        UsageEventSender("", "", isOptedIn = { true }).invoke(AppAnalyticsEvent.ACTIVE_DAY)
    }
}

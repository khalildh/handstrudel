package com.handstrudel.ui.social

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant

/** iOS `Text(date, style: .relative)`: two largest units, abbreviated, no "ago". */
class RelativeTimeTest {
    @Test fun twoLargestUnits() {
        assertEquals("2 hr, 10 min", relativeTimeSpan(2 * 3600L + 10 * 60L + 5))
        assertEquals("1 hr, 26 min", relativeTimeSpan(3600L + 26 * 60L))
        assertEquals("5 min, 3 sec", relativeTimeSpan(5 * 60L + 3))
        assertEquals("3 days, 4 hr", relativeTimeSpan(3 * 86_400L + 4 * 3600L))
        assertEquals("1 day", relativeTimeSpan(86_400L + 5 * 60L))
        assertEquals("2 wks, 1 day", relativeTimeSpan(15 * 86_400L))
    }

    @Test fun shortAndFutureSpans() {
        assertEquals("45 sec", relativeTimeSpan(45))
        assertEquals("0 sec", relativeTimeSpan(0))
        val now = 1_000_000_000L
        assertEquals("0 sec", relativeTime(Instant.ofEpochMilli(now + 5_000), now))
        assertEquals("", relativeTime(null, now))
    }
}

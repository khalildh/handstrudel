package com.handstrudel.capture

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ProjectionPolicyTest {
    @Test fun consentIsReusableBeforeAndroid14() {
        for (sdk in 29..33) assertTrue("API $sdk", ProjectionPolicy.canReuseConsent(sdk))
    }

    @Test fun consentIsSingleUseFromAndroid14() {
        for (sdk in 34..36) assertFalse("API $sdk", ProjectionPolicy.canReuseConsent(sdk))
    }
}

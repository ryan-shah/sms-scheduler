package com.rsh.sms_sender

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class SendAggregatorTest {
    private val ok = SendAggregator.RESULT_OK

    @Test
    fun allPartsOk_isSent() {
        val a = SendAggregator(3)
        assertNull(a.onPartResult(ok))
        assertNull(a.onPartResult(ok))
        assertEquals(SendAggregator.Outcome("sent", null, 3), a.onPartResult(ok))
    }

    @Test
    fun onePartFails_isFailedWithFirstError() {
        val a = SendAggregator(3)
        assertNull(a.onPartResult(ok))
        assertNull(a.onPartResult(4))
        assertEquals(SendAggregator.Outcome("failed", 4, 3), a.onPartResult(2))
    }

    @Test
    fun missingParts_timeout() {
        val a = SendAggregator(2)
        assertNull(a.onPartResult(ok))
        assertEquals(SendAggregator.Outcome("timeout", null, 2), a.onTimeout())
    }

    @Test
    fun singlePart() {
        assertEquals(SendAggregator.Outcome("sent", null, 1), SendAggregator(1).onPartResult(ok))
        assertEquals(SendAggregator.Outcome("failed", 1, 1), SendAggregator(1).onPartResult(1))
    }

    @Test
    fun timeoutAfterComplete_keepsOutcome() {
        val a = SendAggregator(1)
        a.onPartResult(ok)
        assertEquals("sent", a.onTimeout().status)
    }
}

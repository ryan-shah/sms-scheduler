package com.rsh.sms_sender

/**
 * Pure aggregation of per-part SENT results (no Android dependencies).
 *
 * `sent` when every part reported RESULT_OK; `failed` with the first error code
 * (in report order) otherwise; `timeout` if [onTimeout] fires before all parts
 * reported. Not thread-safe: callers must serialise access (the plugin uses the
 * main looper).
 */
class SendAggregator(private val parts: Int) {
    data class Outcome(val status: String, val errorCode: Int?, val parts: Int) {
        fun toMap(): Map<String, Any?> =
            mapOf("status" to status, "errorCode" to errorCode, "parts" to parts)
    }

    companion object {
        const val RESULT_OK = -1 // android.app.Activity.RESULT_OK
        const val TIMEOUT_MS = 30_000L
    }

    private var reported = 0
    private var firstError: Int? = null
    private var outcome: Outcome? = null

    /** Records one part's result; returns the final outcome once all parts reported. */
    fun onPartResult(resultCode: Int): Outcome? {
        outcome?.let { return it }
        reported++
        if (resultCode != RESULT_OK && firstError == null) firstError = resultCode
        if (reported >= parts) {
            outcome = Outcome(if (firstError == null) "sent" else "failed", firstError, parts)
        }
        return outcome
    }

    /** Finalises as timeout unless already complete. */
    fun onTimeout(): Outcome {
        outcome?.let { return it }
        return Outcome("timeout", null, parts).also { outcome = it }
    }
}

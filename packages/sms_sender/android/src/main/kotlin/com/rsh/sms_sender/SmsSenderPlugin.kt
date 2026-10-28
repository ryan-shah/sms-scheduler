package com.rsh.sms_sender

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.atomic.AtomicInteger

/** Thin Android wrapper around [SendAggregator]. */
class SmsSenderPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val handler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.rsh.sms_sender")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method != "send") {
            result.notImplemented()
            return
        }
        val to = call.argument<String>("to")
        val body = call.argument<String>("body")
        val subId = call.argument<Int>("subscriptionId")
        if (to == null || body == null) {
            result.error("bad_args", "to and body are required", null)
            return
        }
        try {
            send(to, body, subId, result)
        } catch (e: Exception) {
            // e.g. SecurityException when SEND_SMS is not granted.
            result.success(SendAggregator.Outcome("failed", ERROR_EXCEPTION, 0).toMap())
        }
    }

    private fun smsManager(subId: Int?): SmsManager {
        if (subId != null) {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                context.getSystemService(SmsManager::class.java).createForSubscriptionId(subId)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getSmsManagerForSubscriptionId(subId)
            }
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
    }

    private fun send(to: String, body: String, subId: Int?, result: Result) {
        val sms = smsManager(subId)
        val texts = sms.divideMessage(body)
        val count = texts.size
        val aggregator = SendAggregator(count)
        val action = "com.rsh.sms_sender.SENT." + nextSendId.incrementAndGet()
        var finished = false
        var receiver: BroadcastReceiver? = null

        fun finish(outcome: SendAggregator.Outcome) {
            if (finished) return
            finished = true
            handler.removeCallbacksAndMessages(action)
            try {
                receiver?.let { context.unregisterReceiver(it) }
            } catch (_: IllegalArgumentException) {
                // already unregistered
            }
            result.success(outcome.toMap())
        }

        receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                aggregator.onPartResult(resultCode)?.let { finish(it) }
            }
        }
        val filter = IntentFilter(action)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(receiver, filter)
        }

        try {
            val base = nextRequestCode.getAndAdd(count)
            val sentIntents = ArrayList<PendingIntent>(count)
            for (i in 0 until count) {
                val intent = Intent(action).setPackage(context.packageName)
                sentIntents.add(
                    PendingIntent.getBroadcast(
                        context, base + i, intent, PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }
            handler.postAtTime(
                { finish(aggregator.onTimeout()) },
                action,
                android.os.SystemClock.uptimeMillis() + SendAggregator.TIMEOUT_MS,
            )
            sms.sendMultipartTextMessage(to, null, texts, sentIntents, null)
        } catch (e: Exception) {
            finish(SendAggregator.Outcome("failed", ERROR_EXCEPTION, count))
        }
    }

    companion object {
        /** Plugin-specific error code when sending threw (not an SmsManager code). */
        const val ERROR_EXCEPTION = -1000
        private val nextSendId = AtomicInteger(0)
        private val nextRequestCode = AtomicInteger(1)
    }
}

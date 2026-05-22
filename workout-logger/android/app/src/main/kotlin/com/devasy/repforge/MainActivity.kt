package com.devasy.repforge

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI and bridges OS-agent write invocations.
 *
 * When an AppFunction write (`createCustomExercise` / `createRoutine`) is
 * invoked it launches this activity with a JSON payload in the
 * [EXTRA_AGENT_ACTION] intent extra. Flutter drains it via the
 * `repforge/agent` method channel and shows a confirmation screen.
 */
class MainActivity : FlutterActivity() {
    private var agentChannel: MethodChannel? = null
    private var pendingAgentAction: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        pendingAgentAction = intent?.getStringExtra(EXTRA_AGENT_ACTION)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AGENT_CHANNEL,
        )
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingAgentAction" -> {
                    val action = pendingAgentAction
                    pendingAgentAction = null
                    result.success(action)
                }
                else -> result.notImplemented()
            }
        }
        agentChannel = channel
    }

    /** Warm-start path: the activity is reused (singleTop) for a new write. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = intent.getStringExtra(EXTRA_AGENT_ACTION) ?: return
        val channel = agentChannel
        if (channel != null) {
            channel.invokeMethod("presentAgentAction", action)
        } else {
            pendingAgentAction = action
        }
    }

    companion object {
        const val AGENT_CHANNEL = "repforge/agent"
        const val EXTRA_AGENT_ACTION = "agent_action"
    }
}

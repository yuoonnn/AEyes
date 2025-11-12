package com.example.aeyes_user_app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aeyes.media_control"
    private var audioManager: AudioManager? = null
    private var mediaSessionManager: MediaSessionManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    result.success(hasNotificationAccess())
                }
                "hasPermission" -> {
                    result.success(hasNotificationAccess())
                }
                "requestPermission" -> {
                    openNotificationAccessSettings()
                    result.success(true)
                }
                "playPause" -> {
                    try {
                        withMediaController { controller ->
                            val state = controller.playbackState?.state
                            if (state == PlaybackState.STATE_PLAYING || state == PlaybackState.STATE_BUFFERING) {
                                controller.transportControls.pause()
                            } else {
                                controller.transportControls.play()
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PLAY_PAUSE_ERROR", e.message, null)
                    }
                }
                "nextTrack" -> {
                    try {
                        withMediaController { it.transportControls.skipToNext() }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NEXT_TRACK_ERROR", e.message, null)
                    }
                }
                "previousTrack" -> {
                    try {
                        withMediaController { it.transportControls.skipToPrevious() }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PREVIOUS_TRACK_ERROR", e.message, null)
                    }
                }
                "volumeUp" -> {
                    try {
                        var handled = false
                        handled = withMediaControllerNullable {
                            it.adjustVolume(AudioManager.ADJUST_RAISE, AudioManager.FLAG_SHOW_UI)
                        }
                        if (!handled) {
                            audioManager?.adjustVolume(AudioManager.ADJUST_RAISE, AudioManager.FLAG_SHOW_UI)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VOLUME_UP_ERROR", e.message, null)
                    }
                }
                "volumeDown" -> {
                    try {
                        var handled = false
                        handled = withMediaControllerNullable {
                            it.adjustVolume(AudioManager.ADJUST_LOWER, AudioManager.FLAG_SHOW_UI)
                        }
                        if (!handled) {
                            audioManager?.adjustVolume(AudioManager.ADJUST_LOWER, AudioManager.FLAG_SHOW_UI)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VOLUME_DOWN_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasNotificationAccess(): Boolean {
        val contentResolver = contentResolver ?: return false
        val component = ComponentName(this, MediaControlNotificationListener::class.java)
        val enabledListeners = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return enabledListeners?.contains(component.flattenToString()) == true
    }

    private fun openNotificationAccessSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun withMediaController(action: (MediaController) -> Unit) {
        val controller = requireController()
        action(controller)
    }

    private fun withMediaControllerNullable(action: (MediaController) -> Unit): Boolean {
        return try {
            val controller = requireController()
            action(controller)
            true
        } catch (e: IllegalStateException) {
            if (e.message?.contains("Notification access") == true) {
                throw e
            }
            false
        }
    }

    private fun getActiveController(): MediaController? {
        if (!hasNotificationAccess()) {
            return null
        }
        val component = ComponentName(this, MediaControlNotificationListener::class.java)
        val controllers = mediaSessionManager?.getActiveSessions(component).orEmpty()
        return controllers.firstOrNull { controller ->
            controller.playbackState != null
        }
    }

    private fun requireController(): MediaController {
        if (!hasNotificationAccess()) {
            throw IllegalStateException("Notification access required. Enable it in Settings > Notifications > Notification Access.")
        }
        val controller = getActiveController()
            ?: throw IllegalStateException("No active media session detected. Start playback in your media app and try again.")
        return controller
    }
}

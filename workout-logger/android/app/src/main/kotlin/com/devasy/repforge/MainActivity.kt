package com.devasy.repforge

import android.app.Dialog
import android.media.MediaMetadataRetriever
import android.media.AudioManager
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.MediaController
import android.widget.VideoView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var videoDialog: Dialog? = null
    private var videoView: VideoView? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "repforge/exercise_media")
            .setMethodCallHandler { call, result ->
                val path = call.argument<String>("path")
                when (call.method) {
                    "videoDuration" -> {
                        if (path == null) {
                            result.error("invalid", "No video selected.", null)
                        } else {
                            Thread {
                                val retriever = MediaMetadataRetriever()
                                try {
                                    retriever.setDataSource(path)
                                    val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toIntOrNull()
                                    val hasVideo = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) == "yes"
                                    if (!hasVideo || duration == null || duration !in 1..60000) {
                                        throw IllegalArgumentException("Choose a playable MP4 video of at most 60 seconds.")
                                    }
                                    runOnUiThread { result.success(duration) }
                                } catch (_: Exception) {
                                    runOnUiThread { result.error("invalid", "Choose a playable MP4 video of at most 60 seconds.", null) }
                                } finally { retriever.release() }
                            }.start()
                        }
                    }
                    "playVideo" -> {
                        val file = path?.let { File(it).canonicalFile }
                        val root = File(applicationInfo.dataDir).canonicalPath + File.separator
                        if (file == null || !file.path.startsWith(root) || !file.isFile) {
                            result.error("missing", "The demonstration is unavailable. Replace it in Edit Exercise.", null)
                        } else {
                            showVideo(file.path, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun showVideo(path: String, result: MethodChannel.Result) {
        videoDialog?.dismiss()
        val dialog = Dialog(this)
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        val video = VideoView(this)
        // A muted technique clip should not stop the lifter's music.
        video.setAudioFocusRequest(AudioManager.AUDIOFOCUS_NONE)
        val controller = MediaController(this)
        controller.setAnchorView(video)
        video.setMediaController(controller)
        layout.addView(video, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        var muted = true
        var player: android.media.MediaPlayer? = null
        val sound = Button(this).apply {
            text = "Enable sound"
            setOnClickListener {
                muted = !muted
                player?.setVolume(if (muted) 0f else 1f, if (muted) 0f else 1f)
                text = if (muted) "Enable sound" else "Mute"
            }
        }
        layout.addView(sound)
        layout.addView(Button(this).apply { text = "Close"; setOnClickListener { dialog.dismiss() } })
        dialog.setContentView(layout)
        var completed = false
        dialog.setOnDismissListener {
            video.stopPlayback()
            if (videoDialog === dialog) { videoDialog = null; videoView = null }
            if (!completed) { completed = true; result.success(null) }
        }
        video.setOnPreparedListener { mp ->
            player = mp
            mp.setVolume(0f, 0f)
            if (mp.duration !in 1..60000) {
                if (!completed) { completed = true; result.error("invalid", "Videos must be at most 60 seconds.", null) }
                dialog.dismiss()
            } else { video.start(); controller.show() }
        }
        video.setOnErrorListener { _, _, _ ->
            if (!completed) { completed = true; result.error("playback", "This video cannot be played. Try another MP4 file.", null) }
            dialog.dismiss()
            true
        }
        videoDialog = dialog
        videoView = video
        dialog.show()
        dialog.window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, (resources.displayMetrics.heightPixels * 0.8).toInt())
        video.setVideoPath(path)
    }

    override fun onPause() { videoView?.pause(); super.onPause() }
    override fun onDestroy() { videoDialog?.dismiss(); super.onDestroy() }
}

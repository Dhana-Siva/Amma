package com.dhana.amma.services

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

/**
 * Plays reply audio and suspends until playback finishes, errors, or 30s
 * elapses — matching iOS's AudioPlaybackService.play(url:), whose caller
 * (TalkViewModel) executes any returned action only after this returns.
 *
 * Forces output to the phone's built-in speaker even if a Bluetooth device
 * is connected, mirroring an iOS bug fix where replies silently routed to
 * a connected Bluetooth A2DP device instead of being heard. Android has no
 * hard-guarantee equivalent of iOS's overrideOutputAudioPort — this uses
 * ExoPlayer.setPreferredAudioDevice(TYPE_BUILTIN_SPEAKER), which Android's
 * own docs describe as a preference, not a guarantee. Needs verification
 * on a real device with a Bluetooth peripheral actually connected.
 */
class AudioPlaybackService(private val context: Context) {

    suspend fun play(url: String) = withContext(Dispatchers.Main) {
        val player = ExoPlayer.Builder(context).build()
        try {
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_SPEECH)
                    .build(),
                /* handleAudioFocus = */ true,
            )
            preferBuiltInSpeaker(player)

            withTimeoutOrNull(30_000) {
                suspendCancellableCoroutine<Unit> { continuation ->
                    val listener = object : Player.Listener {
                        override fun onPlaybackStateChanged(playbackState: Int) {
                            if (playbackState == Player.STATE_ENDED && continuation.isActive) {
                                continuation.resume(Unit)
                            }
                        }

                        override fun onPlayerError(error: PlaybackException) {
                            if (continuation.isActive) continuation.resume(Unit)
                        }
                    }
                    player.addListener(listener)
                    continuation.invokeOnCancellation { player.removeListener(listener) }

                    player.setMediaItem(MediaItem.fromUri(url))
                    player.prepare()
                    player.play()
                }
            }
        } finally {
            player.release()
        }
    }

    private fun preferBuiltInSpeaker(player: ExoPlayer) {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        val speaker = audioManager
            .getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
        if (speaker != null) {
            player.setPreferredAudioDevice(speaker)
        }
    }
}

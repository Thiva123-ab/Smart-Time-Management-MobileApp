package com.focusflow.focusflow

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.MediaPlayer
import android.os.Build
import java.util.Random
import kotlin.math.sin

object FocusAudioEngine {

    private var mediaPlayer: MediaPlayer? = null
    private var audioTrack: AudioTrack? = null
    private var synthThread: Thread? = null
    @Volatile private var isSynthesizing = false

    private var currentSound: String = ""
    private var currentVolume: Float = 0.7f

    // Nature audio streaming URLs (reliable public domain ambient loops)
    private val ambientUrls = mapOf(
        "rain" to "https://actions.google.com/sounds/v1/weather/rain_heavy.ogg",
        "forest" to "https://actions.google.com/sounds/v1/ambiences/outdoor_ambience.ogg",
        "ocean" to "https://actions.google.com/sounds/v1/water/waves_crashing.ogg"
    )

    fun playSound(context: Context, soundType: String, volume: Float = 0.7f): Boolean {
        stopSound()
        currentSound = soundType
        currentVolume = volume.coerceIn(0f, 1f)

        return when (soundType) {
            "binaural_gamma" -> {
                // 40Hz difference (200Hz Left, 240Hz Right) for Gamma Focus
                startBinauralSynthesis(200.0, 240.0)
                true
            }
            "binaural_alpha" -> {
                // 10Hz difference (200Hz Left, 210Hz Right) for Alpha Relaxation & Calm Focus
                startBinauralSynthesis(200.0, 210.0)
                true
            }
            "white_noise" -> {
                startWhiteNoiseSynthesis()
                true
            }
            "rain", "forest", "ocean" -> {
                playStream(ambientUrls[soundType] ?: "")
            }
            else -> false
        }
    }

    private fun startBinauralSynthesis(leftFreq: Double, rightFreq: Double) {
        val sampleRate = 44100
        val minBuf = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_STEREO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        audioTrack = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                        .build()
                )
                .setBufferSizeInBytes(minBuf * 2)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
        } else {
            @Suppress("DEPRECATION")
            AudioTrack(
                android.media.AudioManager.STREAM_MUSIC,
                sampleRate,
                AudioFormat.CHANNEL_OUT_STEREO,
                AudioFormat.ENCODING_PCM_16BIT,
                minBuf * 2,
                AudioTrack.MODE_STREAM
            )
        }

        audioTrack?.setVolume(currentVolume)
        audioTrack?.play()

        isSynthesizing = true
        synthThread = Thread {
            val buffer = ShortArray(2048)
            var phaseL = 0.0
            var phaseR = 0.0
            val deltaL = 2.0 * Math.PI * leftFreq / sampleRate
            val deltaR = 2.0 * Math.PI * rightFreq / sampleRate

            while (isSynthesizing) {
                var i = 0
                while (i < buffer.size) {
                    val sampleL = (sin(phaseL) * 16000.0).toInt().coerceIn(-32768, 32767).toShort()
                    val sampleR = (sin(phaseR) * 16000.0).toInt().coerceIn(-32768, 32767).toShort()

                    buffer[i] = sampleL
                    buffer[i + 1] = sampleR

                    phaseL += deltaL
                    phaseR += deltaR
                    if (phaseL > 2.0 * Math.PI) phaseL -= 2.0 * Math.PI
                    if (phaseR > 2.0 * Math.PI) phaseR -= 2.0 * Math.PI

                    i += 2
                }
                audioTrack?.write(buffer, 0, buffer.size)
            }
        }.apply { start() }
    }

    private fun startWhiteNoiseSynthesis() {
        val sampleRate = 44100
        val minBuf = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_STEREO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        audioTrack = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                        .build()
                )
                .setBufferSizeInBytes(minBuf * 2)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
        } else {
            @Suppress("DEPRECATION")
            AudioTrack(
                android.media.AudioManager.STREAM_MUSIC,
                sampleRate,
                AudioFormat.CHANNEL_OUT_STEREO,
                AudioFormat.ENCODING_PCM_16BIT,
                minBuf * 2,
                AudioTrack.MODE_STREAM
            )
        }

        audioTrack?.setVolume(currentVolume)
        audioTrack?.play()

        isSynthesizing = true
        val random = Random()
        synthThread = Thread {
            val buffer = ShortArray(2048)
            var lastL = 0.0
            var lastR = 0.0

            while (isSynthesizing) {
                var i = 0
                while (i < buffer.size) {
                    // Soft filtered pink/white noise
                    val rawL = (random.nextDouble() * 2.0 - 1.0) * 12000.0
                    val rawR = (random.nextDouble() * 2.0 - 1.0) * 12000.0

                    lastL = lastL * 0.7 + rawL * 0.3
                    lastR = lastR * 0.7 + rawR * 0.3

                    buffer[i] = lastL.toInt().coerceIn(-32768, 32767).toShort()
                    buffer[i + 1] = lastR.toInt().coerceIn(-32768, 32767).toShort()
                    i += 2
                }
                audioTrack?.write(buffer, 0, buffer.size)
            }
        }.apply { start() }
    }

    private fun playStream(url: String): Boolean {
        if (url.isEmpty()) return false
        return try {
            mediaPlayer = MediaPlayer().apply {
                setDataSource(url)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                isLooping = true
                setVolume(currentVolume, currentVolume)
                prepareAsync()
                setOnPreparedListener { it.start() }
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    fun setVolume(vol: Float) {
        currentVolume = vol.coerceIn(0f, 1f)
        mediaPlayer?.setVolume(currentVolume, currentVolume)
        audioTrack?.setVolume(currentVolume)
    }

    fun stopSound() {
        isSynthesizing = false
        try {
            synthThread?.interrupt()
            synthThread = null
        } catch (_: Exception) {}

        try {
            audioTrack?.stop()
            audioTrack?.release()
            audioTrack = null
        } catch (_: Exception) {}

        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (_: Exception) {}

        currentSound = ""
    }

    fun isPlaying(): Boolean {
        return isSynthesizing || (mediaPlayer?.isPlaying == true)
    }

    fun getCurrentSound(): String = currentSound
}

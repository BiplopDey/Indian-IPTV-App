package com.nk.live_tv

import android.content.Context
import android.graphics.Color
import android.net.Uri
import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.Util
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class TvPlayerViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return TvPlayerView(context, args)
    }
}

class TvPlayerView(
    context: Context,
    args: Any?
) : PlatformView {
    private val logTag = "TvPlayerView"
    private val httpDataSourceFactory = DefaultHttpDataSource.Factory()
        .setAllowCrossProtocolRedirects(true)
        .setUserAgent("Mozilla/5.0")
    private val mediaSourceFactory = DefaultMediaSourceFactory(
        DefaultDataSource.Factory(context, httpDataSourceFactory)
    )
    private val renderersFactory = DefaultRenderersFactory(context)
        .setEnableDecoderFallback(true)
        .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)
    private val player: ExoPlayer = ExoPlayer.Builder(context, renderersFactory)
        .setMediaSourceFactory(mediaSourceFactory)
        .build()
    private val playerView: PlayerView = PlayerView(context).apply {
        this.player = this@TvPlayerView.player
        useController = false
        keepScreenOn = true
        resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        setShutterBackgroundColor(Color.BLACK)
        requestFocus()
    }

    init {
        player.addListener(object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) {
                Log.e(logTag, "Playback error: ${error.errorCodeName}", error)
            }
        })

        val url = (args as? Map<*, *>)?.get("url") as? String
        if (!url.isNullOrBlank()) {
            val uri = Uri.parse(url)
            val urlText = uri.toString().lowercase()
            val mediaItemBuilder = MediaItem.Builder()
                .setUri(uri)
            val explicitMimeType = when {
                urlText.contains(".m3u8") -> MimeTypes.APPLICATION_M3U8
                urlText.contains(".mpd") -> MimeTypes.APPLICATION_MPD
                urlText.contains(".ism") -> MimeTypes.APPLICATION_SS
                else -> null
            }
            if (explicitMimeType != null) {
                mediaItemBuilder.setMimeType(explicitMimeType)
            } else {
                when (Util.inferContentType(uri)) {
                    C.CONTENT_TYPE_HLS -> mediaItemBuilder.setMimeType(MimeTypes.APPLICATION_M3U8)
                    C.CONTENT_TYPE_DASH -> mediaItemBuilder.setMimeType(MimeTypes.APPLICATION_MPD)
                    C.CONTENT_TYPE_SS -> mediaItemBuilder.setMimeType(MimeTypes.APPLICATION_SS)
                }
            }
            val mediaItem = mediaItemBuilder.build()
            player.setMediaItem(mediaItem)
            player.playWhenReady = true
            player.prepare()
        }
    }

    override fun getView(): PlayerView = playerView

    override fun dispose() {
        playerView.player = null
        player.release()
    }
}

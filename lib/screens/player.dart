import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../config/app_config.dart';
import '../domain/entities/channel.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class Player extends StatefulWidget {
  final List<Channel> channels;
  final int initialIndex;

  const Player({
    required this.channels,
    required this.initialIndex,
    super.key,
  });

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  bool get _isTv => AppConfig.isTv;
  VideoPlayerController? videoPlayerController;
  ChewieController? chewieController;
  late int _currentIndex;
  int _loadToken = 0;
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = true;
  bool _channelNotFound = false;
  String? _nativeStreamUrl;
  int _nativeViewKey = 0;
  Timer? _overlayTimer;
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _currentIndex = widget.initialIndex;
    _showOverlayFor(const Duration(seconds: 4));
    _loadChannel(_currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _loadChannel(int index) async {
    final int loadToken = ++_loadToken;
    setState(() {
      _isLoading = true;
      _channelNotFound = false;
    });
    _showOverlayFor(const Duration(seconds: 4));

    await _disposeControllers();

    final channel = widget.channels[index];
    if (channel.streamUrl.trim().isEmpty) {
      if (!mounted || loadToken != _loadToken) {
        return;
      }
      setState(() {
        _isLoading = false;
        _channelNotFound = true;
      });
      return;
    }

    if (_isTv && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _nativeStreamUrl = channel.streamUrl;
      _nativeViewKey++;
      WakelockPlus.enable();
      if (!mounted || loadToken != _loadToken) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      _showOverlayFor(const Duration(seconds: 3));
      return;
    }

    final controller =
        VideoPlayerController.networkUrl(Uri.parse(channel.streamUrl));
    videoPlayerController = controller;

    controller.addListener(() {
      if (!mounted) {
        return;
      }
      if (controller.value.isPlaying) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    });

    try {
      await controller.initialize();
      if (!mounted || loadToken != _loadToken) {
        await controller.dispose();
        return;
      }
      chewieController = ChewieController(
        videoPlayerController: controller,
        autoInitialize: true,
        isLive: true,
        autoPlay: true,
        aspectRatio: controller.value.aspectRatio,
        showOptions: false,
        customControls: const MaterialDesktopControls(
          showPlayButton: false,
        ),
      );
      setState(() {
        _isLoading = false;
      });
      _showOverlayFor(const Duration(seconds: 3));
    } catch (error) {
      await controller.dispose();
      if (!mounted || loadToken != _loadToken) {
        return;
      }
      setState(() {
        _isLoading = false;
        _channelNotFound = true;
      });
    }
  }

  Future<void> _disposeControllers() async {
    final controller = videoPlayerController;
    final chewie = chewieController;
    videoPlayerController = null;
    chewieController = null;
    _nativeStreamUrl = null;
    if (controller != null) {
      await controller.dispose();
    }
    chewie?.dispose();
    await WakelockPlus.disable();
  }

  void _changeChannel(int newIndex) {
    final totalChannels = widget.channels.length;
    if (totalChannels == 0) {
      return;
    }
    final wrappedIndex = newIndex % totalChannels;
    final normalizedIndex =
        wrappedIndex < 0 ? wrappedIndex + totalChannels : wrappedIndex;
    if (normalizedIndex == _currentIndex) {
      return;
    }
    setState(() {
      _currentIndex = normalizedIndex;
    });
    _showOverlayFor(const Duration(seconds: 4));
    _loadChannel(normalizedIndex);
  }

  void _showOverlayFor(Duration duration) {
    if (!_isTv) {
      return;
    }
    _overlayTimer?.cancel();
    if (mounted) {
      setState(() {
        _showOverlay = true;
      });
    }
    _overlayTimer = Timer(duration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showOverlay = false;
      });
    });
  }

  Widget _buildPlayerSurface() {
    if (_isTv &&
        _nativeStreamUrl != null &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      return _buildNativeTvPlayerView(context);
    }
    if (chewieController == null) {
      return const SizedBox.shrink();
    }
    return Chewie(controller: chewieController!);
  }

  Widget _buildChannelLogo(Channel channel) {
    final logoUrl = channel.logoUrl.trim();
    if (logoUrl.isEmpty) {
      return Image.asset(
        'assets/images/tv-icon.png',
        width: 48,
        height: 48,
        fit: BoxFit.contain,
      );
    }
    return Image.network(
      logoUrl,
      width: 48,
      height: 48,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/tv-icon.png',
          width: 48,
          height: 48,
          fit: BoxFit.contain,
        );
      },
    );
  }

  Widget _buildTvOverlay(Channel channel) {
    final bool overlayVisible = _showOverlay || _isLoading || _channelNotFound;
    final String groupTitle = channel.groupTitle.trim();
    return IgnorePointer(
      ignoring: true,
      child: AnimatedOpacity(
        opacity: overlayVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: Stack(
          children: [
            Positioned(
              left: 24,
              top: 24,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(166),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withAlpha(38),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildChannelLogo(channel),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CH ${_currentIndex + 1}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          channel.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (groupTitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            groupTitle,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(179),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Switching channel...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_channelNotFound)
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(179),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tv_off, color: Colors.white70, size: 34),
                      SizedBox(height: 12),
                      Text(
                        'No signal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Try another channel',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNativeTvPlayerView(BuildContext context) {
    return PlatformViewLink(
      key: ValueKey('tv-player-$_nativeViewKey'),
      viewType: 'tv-player',
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        final controller = PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: 'tv-player',
          layoutDirection: Directionality.of(context),
          creationParams: {
            'url': _nativeStreamUrl,
          },
          creationParamsCodec: const StandardMessageCodec(),
        );
        controller
            .addOnPlatformViewCreatedListener(params.onPlatformViewCreated);
        controller.create();
        return controller;
      },
    );
  }

  @override
  void dispose() {
    _disposeControllers();
    _focusNode.dispose();
    _overlayTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.channels.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No channels available'),
        ),
      );
    }

    final channel = widget.channels[_currentIndex];

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.arrowUp):
            const _PreviousChannelIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _NextChannelIntent(),
        LogicalKeySet(LogicalKeyboardKey.channelUp): const _NextChannelIntent(),
        LogicalKeySet(LogicalKeyboardKey.channelDown):
            const _PreviousChannelIntent(),
        LogicalKeySet(LogicalKeyboardKey.select): const _ShowOverlayIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const _ShowOverlayIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter):
            const _ShowOverlayIntent(),
        LogicalKeySet(LogicalKeyboardKey.info): const _ShowOverlayIntent(),
        if (kIsWeb)
          LogicalKeySet(LogicalKeyboardKey.escape): const _ExitPlayerIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _PreviousChannelIntent: CallbackAction<_PreviousChannelIntent>(
            onInvoke: (intent) {
              _changeChannel(_currentIndex - 1);
              return null;
            },
          ),
          _NextChannelIntent: CallbackAction<_NextChannelIntent>(
            onInvoke: (intent) {
              _changeChannel(_currentIndex + 1);
              return null;
            },
          ),
          _ShowOverlayIntent: CallbackAction<_ShowOverlayIntent>(
            onInvoke: (intent) {
              _showOverlayFor(const Duration(seconds: 4));
              return null;
            },
          ),
          _ExitPlayerIntent: CallbackAction<_ExitPlayerIntent>(
            onInvoke: (intent) {
              Navigator.of(context).maybePop();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: Scaffold(
            body: _isTv
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.black),
                      if (!_channelNotFound) _buildPlayerSurface(),
                      _buildTvOverlay(channel),
                    ],
                  )
                : _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _channelNotFound
                        ? const Center(
                            child: Text('Channel not available now',
                                style: TextStyle(fontSize: 24.0)),
                          )
                        : SizedBox.expand(
                            child: _buildPlayerSurface(),
                          ),
          ),
        ),
      ),
    );
  }
}

class _PreviousChannelIntent extends Intent {
  const _PreviousChannelIntent();
}

class _NextChannelIntent extends Intent {
  const _NextChannelIntent();
}

class _ShowOverlayIntent extends Intent {
  const _ShowOverlayIntent();
}

class _ExitPlayerIntent extends Intent {
  const _ExitPlayerIntent();
}

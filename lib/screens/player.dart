import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../adapters/outbound/cast_client_factory.dart';
import '../application/cast_session_service.dart';
import '../config/app_config.dart';
import '../domain/entities/cast_connection_state.dart';
import '../domain/entities/cast_device.dart';
import '../domain/entities/cast_media_item.dart';
import '../domain/entities/channel.dart';

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
  bool get _canCast => _castService != null;

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
  CastSessionService? _castService;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _currentIndex = widget.initialIndex;
    _showOverlayFor(const Duration(seconds: 4));
    _loadChannel(_currentIndex);
    if (!_isTv) {
      final client = createCastClient(appId: AppConfig.defaultCastAppId);
      if (client != null) {
        _castService = CastSessionService(client: client);
        unawaited(_castService!.initialize());
      }
    }
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

  CastMediaItem _buildCastMediaItem(Channel channel) {
    final logoUrl = channel.logoUrl.trim();
    final groupTitle = channel.groupTitle.trim();
    return CastMediaItem(
      streamUrl: Uri.parse(channel.streamUrl),
      title: channel.name,
      subtitle: groupTitle.isEmpty ? null : groupTitle,
      imageUrl: logoUrl.isEmpty ? null : Uri.tryParse(logoUrl),
    );
  }

  Future<void> _showCastDeviceSheet(Channel channel) async {
    final castService = _castService;
    if (castService == null) {
      return;
    }
    final streamUrl = channel.streamUrl.trim();
    if (streamUrl.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stream URL available for casting.')),
      );
      return;
    }

    final media = _buildCastMediaItem(channel);
    bool discoveryStarted = false;
    try {
      await castService.startDiscovery();
      discoveryStarted = true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cast unavailable: $error')),
        );
      }
      return;
    }
    if (!mounted) {
      if (discoveryStarted) {
        await castService.stopDiscovery();
      }
      return;
    }

    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF15161C),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cast, color: Colors.white),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Cast to device',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 240,
                    child: StreamBuilder<List<CastDevice>>(
                      stream: castService.devicesStream,
                      builder: (context, snapshot) {
                        final devices = snapshot.data ?? const [];
                        if (devices.isEmpty) {
                          return const Center(
                            child: Text(
                              'Searching for devices...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: devices.length,
                          separatorBuilder: (context, index) =>
                              const Divider(color: Colors.white12),
                          itemBuilder: (context, index) {
                            final device = devices[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.tv,
                                color: Colors.white70,
                              ),
                              title: Text(
                                device.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: device.modelName == null
                                  ? null
                                  : Text(
                                      device.modelName!,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                      ),
                                    ),
                              onTap: () => _handleCastDeviceTap(
                                sheetContext,
                                castService,
                                device,
                                media,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<CastConnectionState>(
                    stream: castService.connectionStateStream,
                    initialData: castService.connectionState,
                    builder: (context, snapshot) {
                      if (snapshot.data != CastConnectionState.connected) {
                        return const SizedBox.shrink();
                      }
                      return Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            await castService.disconnect();
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                          icon: const Icon(Icons.stop, color: Colors.white70),
                          label: const Text(
                            'Stop casting',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      if (discoveryStarted) {
        await castService.stopDiscovery();
      }
    }
  }

  Future<void> _handleCastDeviceTap(
    BuildContext sheetContext,
    CastSessionService castService,
    CastDevice device,
    CastMediaItem media,
  ) async {
    try {
      if (castService.connectionState == CastConnectionState.connected) {
        await castService.disconnect();
      }
      await castService.connectAndCast(device: device, media: media);
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Casting failed: $error')),
      );
    }
  }

  Widget _buildCastButton(Channel channel) {
    final castService = _castService;
    if (castService == null) {
      return const SizedBox.shrink();
    }
    return Positioned(
      right: 16,
      bottom: 20,
      child: SafeArea(
        child: StreamBuilder<CastConnectionState>(
          stream: castService.connectionStateStream,
          initialData: castService.connectionState,
          builder: (context, snapshot) {
            final state = snapshot.data ?? CastConnectionState.disconnected;
            final icon = state == CastConnectionState.connected
                ? Icons.cast_connected
                : Icons.cast;
            return Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                key: const ValueKey('cast-button'),
                tooltip: 'Cast',
                icon: Icon(icon, color: Colors.white),
                onPressed: () => _showCastDeviceSheet(channel),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposeControllers();
    final castService = _castService;
    if (castService != null) {
      unawaited(castService.stopDiscovery());
    }
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
                : Stack(
                    children: [
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(),
                        )
                      else if (_channelNotFound)
                        const Center(
                          child: Text('Channel not available now',
                              style: TextStyle(fontSize: 24.0)),
                        )
                      else
                        SizedBox.expand(
                          child: _buildPlayerSurface(),
                        ),
                      if (_canCast) _buildCastButton(channel),
                    ],
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

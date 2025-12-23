import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../model/channel.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class Player extends StatefulWidget {
  final List<Channel> channels;
  final int initialIndex;

  const Player({required this.channels, required this.initialIndex, Key? key})
      : super(key: key);

  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> with WidgetsBindingObserver {
  VideoPlayerController? videoPlayerController;
  ChewieController? chewieController;
  late int _currentIndex;
  int _loadToken = 0;
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = true;
  bool _channelNotFound = false;
  bool _wasPlayingBeforePause = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _currentIndex = widget.initialIndex;
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
    _loadChannel(normalizedIndex);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeControllers();
    _focusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = videoPlayerController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _wasPlayingBeforePause = controller.value.isPlaying;
        controller.pause();
        WakelockPlus.disable();
        break;
      case AppLifecycleState.resumed:
        if (_wasPlayingBeforePause) {
          controller.play();
        }
        _wasPlayingBeforePause = false;
        break;
    }
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
        LogicalKeySet(LogicalKeyboardKey.arrowDown):
            const _NextChannelIntent(),
        if (kIsWeb)
          LogicalKeySet(LogicalKeyboardKey.escape):
              const _ExitPlayerIntent(),
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
            body: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _channelNotFound
                    ? const Center(
                        child: Text('Channel not available now',
                            style: TextStyle(fontSize: 24.0)),
                      )
                    : SizedBox.expand(
                        child: chewieController == null
                            ? const SizedBox.shrink()
                            : Chewie(controller: chewieController!),
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

class _ExitPlayerIntent extends Intent {
  const _ExitPlayerIntent();
}

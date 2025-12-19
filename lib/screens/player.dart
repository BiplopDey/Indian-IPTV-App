import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import '../model/channel.dart';

class Player extends StatefulWidget {
  final List<Channel> channels;
  final int initialIndex;

  const Player({required this.channels, required this.initialIndex, Key? key})
      : super(key: key);

  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  final bool _isTv =
      const String.fromEnvironment('TARGET', defaultValue: 'mobile') == 'tv';
  late final mk.Player _player;
  late final VideoController _videoController;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<String>? _errorSub;
  late int _currentIndex;
  int _loadToken = 0;
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = true;
  bool _channelNotFound = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _showChannelOverlay = false;
  Timer? _overlayTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _player = mk.Player();
    _videoController = VideoController(_player);
    _attachPlayerListeners();
    _currentIndex = widget.initialIndex;
    _loadChannel(_currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _attachPlayerListeners() {
    _playingSub = _player.stream.playing.listen((playing) {
      _isPlaying = playing;
      _updateLoadingState();
    });
    _bufferingSub = _player.stream.buffering.listen((buffering) {
      _isBuffering = buffering;
      _updateLoadingState();
    });
    _errorSub = _player.stream.error.listen((message) {
      if (message.trim().isEmpty) {
        return;
      }
      _isPlaying = false;
      _isBuffering = false;
      if (!mounted) {
        return;
      }
      setState(() {
        _channelNotFound = true;
        _isLoading = false;
      });
    });
  }

  void _updateLoadingState() {
    if (!mounted) {
      return;
    }
    final nextLoading = _isBuffering || !_isPlaying;
    if (nextLoading == _isLoading) {
      return;
    }
    setState(() {
      _isLoading = nextLoading;
    });
  }

  Future<void> _loadChannel(int index) async {
    final int loadToken = ++_loadToken;
    setState(() {
      _isLoading = true;
      _channelNotFound = false;
    });
    _triggerChannelOverlay();

    final channel = widget.channels[index];
    final url = channel.streamUrl.trim();
    if (url.isEmpty) {
      await _player.stop();
      if (!mounted || loadToken != _loadToken) {
        return;
      }
      setState(() {
        _isLoading = false;
        _channelNotFound = true;
      });
      return;
    }

    _isPlaying = false;
    _isBuffering = true;
    _updateLoadingState();

    try {
      await _player.open(mk.Media(url), play: true);
    } catch (_) {
      if (!mounted || loadToken != _loadToken) {
        return;
      }
      setState(() {
        _isLoading = false;
        _channelNotFound = true;
      });
    }
  }

  void _changeChannel(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.channels.length) {
      return;
    }
    if (newIndex == _currentIndex) {
      return;
    }
    setState(() {
      _currentIndex = newIndex;
    });
    _loadChannel(newIndex);
  }

  void _triggerChannelOverlay() {
    if (!_isTv) {
      return;
    }
    _overlayTimer?.cancel();
    setState(() {
      _showChannelOverlay = true;
    });
    _overlayTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showChannelOverlay = false;
      });
    });
  }

  Widget _buildChannelOverlay(Channel channel) {
    final isVisible = _showChannelOverlay || _isLoading;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            margin: const EdgeInsets.all(24.0),
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    'CH ${_currentIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Text(
                  channel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _errorSub?.cancel();
    _player.dispose();
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
        LogicalKeySet(LogicalKeyboardKey.arrowDown):
            const _NextChannelIntent(),
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
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: Scaffold(
            body: SizedBox.expand(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Video(
                      controller: _videoController,
                      fit: BoxFit.cover,
                      controls: NoVideoControls,
                      focusNode: _focusNode,
                    ),
                  ),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                  if (_channelNotFound)
                    const Center(
                      child: Text('Channel not available now',
                          style: TextStyle(fontSize: 24.0)),
                    ),
                  if (_isTv) _buildChannelOverlay(channel),
                ],
              ),
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

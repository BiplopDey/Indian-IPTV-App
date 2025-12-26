// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../../domain/entities/cast_connection_state.dart';
import '../../domain/entities/cast_device.dart';
import '../../domain/entities/cast_media_item.dart';
import '../../domain/ports/cast_client_port.dart';

class WebCastClient implements CastClientPort {
  WebCastClient({
    required String appId,
  }) : _appId = appId;

  final String _appId;
  final StreamController<List<CastDevice>> _devicesController =
      StreamController<List<CastDevice>>.broadcast();
  final StreamController<CastConnectionState> _stateController =
      StreamController<CastConnectionState>.broadcast();
  final CastDevice _selectorDevice = const CastDevice(
    id: 'cast-dialog',
    name: 'Select a device',
  );

  Completer<void>? _readyCompleter;
  bool _initialized = false;
  bool _listenerAttached = false;
  CastConnectionState _state = CastConnectionState.disconnected;

  @override
  Stream<List<CastDevice>> get devicesStream => _devicesController.stream;

  @override
  Stream<CastConnectionState> get connectionStateStream =>
      _stateController.stream;

  @override
  CastConnectionState get connectionState => _state;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await _ensureCastFrameworkReady();
    _initializeContext();
  }

  @override
  Future<void> startDiscovery() async {
    await initialize();
    _devicesController.add([_selectorDevice]);
  }

  @override
  Future<void> stopDiscovery() async {
    _devicesController.add(const []);
  }

  @override
  Future<void> connect(CastDevice device) async {
    await initialize();
    await _requestSession();
  }

  @override
  Future<void> disconnect() async {
    await initialize();
    final context = _getCastContext();
    _callMethod(context, 'endCurrentSession', [true.toJS]);
  }

  @override
  Future<void> loadMedia(CastMediaItem item) async {
    await initialize();
    var session = _getCurrentSession();
    if (session == null) {
      await _requestSession();
      session = _getCurrentSession();
    }
    if (session == null) {
      throw StateError('No active Cast session');
    }
    final request = _buildLoadRequest(item);
    final result = _callMethod(session, 'loadMedia', [request]);
    await _awaitPromise(result);
  }

  Future<void> _ensureCastFrameworkReady() async {
    if (_readyCompleter != null) {
      return _readyCompleter!.future;
    }
    _readyCompleter = Completer<void>();
    if (_hasCastFramework()) {
      _readyCompleter!.complete();
      return _readyCompleter!.future;
    }
    final window = _getWindow();
    window['__onGCastApiAvailable'] = ((JSAny? isAvailable) {
      final bool available = (isAvailable as JSBoolean?)?.toDart ?? false;
      if (available) {
        _readyCompleter?.complete();
      } else {
        _readyCompleter?.completeError(
          StateError('Cast framework not available'),
        );
      }
    }).toJS;
    return _readyCompleter!.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        throw StateError('Cast framework not available');
      },
    );
  }

  bool _hasCastFramework() {
    return _getWindow().has('cast');
  }

  void _initializeContext() {
    final context = _getCastContext();
    final options = _buildCastOptions();
    _callMethod(context, 'setOptions', [options]);
    _attachSessionListener(context);
    _updateStateFromContext(context);
  }

  JSObject _buildCastOptions() {
    final options = JSObject();
    options['receiverApplicationId'] = _appId.toJS;
    final policy = _getAutoJoinPolicy();
    if (policy != null) {
      options['autoJoinPolicy'] = policy;
    }
    return options;
  }

  JSAny? _getAutoJoinPolicy() {
    final chrome = _getObjectProperty(_getWindow(), 'chrome');
    if (chrome == null) {
      return null;
    }
    final chromeCast = _getObjectProperty(chrome, 'cast');
    if (chromeCast == null) {
      return null;
    }
    final autoJoinPolicy = _getObjectProperty(chromeCast, 'AutoJoinPolicy');
    if (autoJoinPolicy == null) {
      return null;
    }
    return autoJoinPolicy['ORIGIN_SCOPED'];
  }

  void _attachSessionListener(JSObject context) {
    if (_listenerAttached) {
      return;
    }
    _listenerAttached = true;
    final eventType = _getCastContextEventType('SESSION_STATE_CHANGED');
    _callMethod(context, 'addEventListener', [
      eventType,
      ((JSAny? event) {
        final sessionState =
            (event as JSObject?)?.getProperty<JSAny?>('sessionState'.toJS);
        _setState(_mapSessionState(sessionState));
      }).toJS,
    ]);
  }

  void _updateStateFromContext(JSObject context) {
    final sessionState = _callMethod(context, 'getSessionState');
    _setState(_mapSessionState(sessionState));
  }

  JSObject _getCastContext() {
    final cast = _getObjectProperty(_getWindow(), 'cast');
    if (cast == null) {
      throw StateError('Cast context is not available');
    }
    final framework = _getObjectProperty(cast, 'framework');
    if (framework == null) {
      throw StateError('Cast framework is not available');
    }
    final contextClass = _getObjectProperty(framework, 'CastContext');
    if (contextClass == null) {
      throw StateError('Cast context class is not available');
    }
    final instance = _callMethod(contextClass, 'getInstance');
    if (instance is! JSObject) {
      throw StateError('Cast context instance is not available');
    }
    return instance;
  }

  JSObject? _getCurrentSession() {
    final context = _getCastContext();
    final session = _callMethod(context, 'getCurrentSession');
    return session is JSObject ? session : null;
  }

  Future<void> _requestSession() async {
    final context = _getCastContext();
    final currentSession = _callMethod(context, 'getCurrentSession');
    if (currentSession != null) {
      return;
    }
    final result = _callMethod(context, 'requestSession');
    await _awaitPromise(result);
  }

  JSObject _buildLoadRequest(CastMediaItem item) {
    final chromeCastMedia = _getChromeCastMedia();
    final mediaInfoCtor = _getObjectProperty(chromeCastMedia, 'MediaInfo');
    if (mediaInfoCtor is! JSFunction) {
      throw StateError('MediaInfo constructor not available');
    }
    final mediaInfo = mediaInfoCtor.callAsConstructorVarArgs<JSObject>([
      item.streamUrl.toString().toJS,
      item.contentType.toJS,
    ]);
    final streamTypeEnum = _getObjectProperty(chromeCastMedia, 'StreamType');
    final streamType = streamTypeEnum == null
        ? null
        : (item.isLive ? streamTypeEnum['LIVE'] : streamTypeEnum['BUFFERED']);
    if (streamType != null) {
      mediaInfo['streamType'] = streamType;
    }

    if (item.title.isNotEmpty || item.subtitle != null) {
      final metadataCtor =
          _getObjectProperty(chromeCastMedia, 'GenericMediaMetadata');
      if (metadataCtor is JSFunction) {
        final metadata = metadataCtor.callAsConstructor<JSObject>();
        if (item.title.isNotEmpty) {
          metadata['title'] = item.title.toJS;
        }
        if (item.subtitle != null) {
          metadata['subtitle'] = item.subtitle!.toJS;
        }
        mediaInfo['metadata'] = metadata;
      }
    }

    final loadRequestCtor = _getObjectProperty(chromeCastMedia, 'LoadRequest');
    if (loadRequestCtor is! JSFunction) {
      throw StateError('LoadRequest constructor not available');
    }
    return loadRequestCtor.callAsConstructorVarArgs<JSObject>([mediaInfo]);
  }

  JSObject _getChromeCastMedia() {
    final chrome = _getObjectProperty(_getWindow(), 'chrome');
    if (chrome == null) {
      throw StateError('Chrome cast bridge not available');
    }
    final chromeCast = _getObjectProperty(chrome, 'cast');
    if (chromeCast == null) {
      throw StateError('Chrome cast bridge not available');
    }
    final media = _getObjectProperty(chromeCast, 'media');
    if (media == null) {
      throw StateError('Chrome cast media namespace not available');
    }
    return media;
  }

  JSAny _getCastContextEventType(String name) {
    final cast = _getObjectProperty(_getWindow(), 'cast');
    if (cast == null) {
      throw StateError('Cast framework is not available');
    }
    final framework = _getObjectProperty(cast, 'framework');
    if (framework == null) {
      throw StateError('Cast framework is not available');
    }
    final eventTypeEnum = _getObjectProperty(framework, 'CastContextEventType');
    if (eventTypeEnum == null) {
      throw StateError('Cast context event type is not available');
    }
    return eventTypeEnum[name] ??
        (throw StateError('Cast context event type not available: $name'));
  }

  CastConnectionState _mapSessionState(JSAny? sessionState) {
    final value = sessionState?.toString() ?? '';
    if (value.contains('SESSION_STARTED') ||
        value.contains('SESSION_RESUMED')) {
      return CastConnectionState.connected;
    }
    if (value.contains('SESSION_STARTING')) {
      return CastConnectionState.connecting;
    }
    if (value.contains('SESSION_ENDING')) {
      return CastConnectionState.disconnecting;
    }
    return CastConnectionState.disconnected;
  }

  void _setState(CastConnectionState next) {
    if (_state == next) {
      return;
    }
    _state = next;
    _stateController.add(next);
  }

  JSObject _getWindow() {
    final window = globalContext['window'];
    if (window is JSObject) {
      return window;
    }
    return globalContext;
  }

  JSObject? _getObjectProperty(JSObject source, String name) {
    final value = source[name];
    return value is JSObject ? value : null;
  }

  JSAny? _callMethod(
    JSObject target,
    String method, [
    List<JSAny?> args = const [],
  ]) {
    if (args.isEmpty) {
      return target.callMethod<JSAny?>(method.toJS);
    }
    return target.callMethodVarArgs<JSAny?>(method.toJS, args);
  }

  Future<void> _awaitPromise(JSAny? promise) async {
    if (promise == null) {
      return;
    }
    await (promise as JSPromise<JSAny?>).toDart;
  }
}

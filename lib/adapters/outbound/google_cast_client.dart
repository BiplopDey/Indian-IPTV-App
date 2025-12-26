import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/cast_context.dart';
import 'package:flutter_chrome_cast/common.dart' as cast_common;
import 'package:flutter_chrome_cast/discovery.dart';
import 'package:flutter_chrome_cast/enums.dart' as cast_enums;
import 'package:flutter_chrome_cast/media.dart';
import 'package:flutter_chrome_cast/models.dart' as cast_models;
import 'package:flutter_chrome_cast/session.dart';
import 'package:flutter_chrome_cast/entities.dart' as cast_entities;

import '../../domain/entities/cast_connection_state.dart';
import '../../domain/entities/cast_device.dart';
import '../../domain/entities/cast_media_item.dart';
import '../../domain/ports/cast_client_port.dart';

class GoogleCastClient implements CastClientPort {
  GoogleCastClient({
    required String appId,
  }) : _appId = appId;

  final String _appId;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }
    _initialized = true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await GoogleCastContext.instance.setSharedInstanceWithOptions(
        cast_models.GoogleCastOptionsAndroid(appId: _appId),
      );
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final discovery = cast_entities.GoogleCastDiscoveryCriteriaInitialize
          .initWithApplicationID(_appId);
      await GoogleCastContext.instance.setSharedInstanceWithOptions(
        cast_models.IOSGoogleCastOptions(discovery),
      );
    }
  }

  @override
  Stream<List<CastDevice>> get devicesStream =>
      GoogleCastDiscoveryManager.instance.devicesStream.map(
        (devices) => devices
            .map(
              (device) => CastDevice(
                id: device.deviceID,
                name: device.friendlyName,
                modelName: device.modelName,
              ),
            )
            .toList(growable: false),
      );

  @override
  Stream<CastConnectionState> get connectionStateStream =>
      GoogleCastSessionManager.instance.currentSessionStream.map(
        (session) => _mapConnectionState(
          session?.connectionState ??
              cast_enums.GoogleCastConnectState.disconnected,
        ),
      );

  @override
  CastConnectionState get connectionState =>
      _mapConnectionState(GoogleCastSessionManager.instance.connectionState);

  @override
  Future<void> startDiscovery() =>
      GoogleCastDiscoveryManager.instance.startDiscovery();

  @override
  Future<void> stopDiscovery() =>
      GoogleCastDiscoveryManager.instance.stopDiscovery();

  @override
  Future<void> connect(CastDevice device) async {
    final devices = GoogleCastDiscoveryManager.instance.devices;
    final target = devices.firstWhere(
      (entry) => entry.deviceID == device.id,
      orElse: () => throw StateError('Cast device not available'),
    );
    await GoogleCastSessionManager.instance.startSessionWithDevice(target);
  }

  @override
  Future<void> disconnect() async {
    await GoogleCastSessionManager.instance.endSessionAndStopCasting();
  }

  @override
  Future<void> loadMedia(CastMediaItem item) async {
    final metadata = cast_entities.GoogleCastGenericMediaMetadata(
      title: item.title,
      subtitle: item.subtitle,
      images: _buildImages(item.imageUrl),
    );
    final mediaInfo = cast_entities.GoogleCastMediaInformation(
      contentId: item.streamUrl.toString(),
      contentUrl: item.streamUrl,
      contentType: item.contentType,
      streamType: item.isLive
          ? cast_enums.CastMediaStreamType.live
          : cast_enums.CastMediaStreamType.buffered,
      metadata: metadata,
    );
    await GoogleCastRemoteMediaClient.instance.loadMedia(mediaInfo);
  }

  List<cast_common.GoogleCastImage>? _buildImages(Uri? imageUrl) {
    if (imageUrl == null) {
      return null;
    }
    return [
      cast_common.GoogleCastImage(
        url: imageUrl,
      ),
    ];
  }

  CastConnectionState _mapConnectionState(
    cast_enums.GoogleCastConnectState state,
  ) {
    switch (state) {
      case cast_enums.GoogleCastConnectState.connected:
        return CastConnectionState.connected;
      case cast_enums.GoogleCastConnectState.connecting:
        return CastConnectionState.connecting;
      case cast_enums.GoogleCastConnectState.disconnecting:
        return CastConnectionState.disconnecting;
      case cast_enums.GoogleCastConnectState.disconnected:
        return CastConnectionState.disconnected;
    }
  }
}

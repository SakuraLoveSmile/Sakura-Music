import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsd/nsd.dart';

/// A server found on the local network via mDNS / DNS-SD.
class DiscoveredServer {
  const DiscoveredServer({
    required this.name,
    required this.host,
    required this.port,
    required this.type,
  });

  final String name;
  final String host;
  final int port;
  final String type;

  /// Human-readable protocol name derived from the service type.
  String get displayType {
    if (type.contains('navidrome')) return 'Navidrome';
    if (type.contains('subsonic')) return 'Subsonic';
    return type;
  }

  @override
  bool operator ==(Object other) =>
      other is DiscoveredServer &&
      other.name == name &&
      other.host == host &&
      other.port == port &&
      other.type == type;

  @override
  int get hashCode => Object.hash(name, host, port, type);

  @override
  String toString() => '$name ($host:$port) [$type]';
}

/// Immutable snapshot exposed by the LAN discovery notifier.
class LanDiscoveryState {
  const LanDiscoveryState({
    this.searching = false,
    this.servers = const <DiscoveredServer>[],
    this.error,
  });

  final bool searching;
  final List<DiscoveredServer> servers;
  final String? error;

  LanDiscoveryState copyWith({
    bool? searching,
    List<DiscoveredServer>? servers,
    String? error,
  }) => LanDiscoveryState(
    searching: searching ?? this.searching,
    servers: servers ?? this.servers,
    error: error ?? this.error,
  );
}

const List<String> _discoveryTypes = <String>[
  '_navidrome._tcp',
  '_subsonic._tcp',
];

final lanDiscoveryProvider =
    NotifierProvider<LanDiscoveryNotifier, LanDiscoveryState>(
      LanDiscoveryNotifier.new,
    );

/// Discovers Navidrome / Subsonic servers on the local network using the
/// platform NSD stack. The page starts and stops discovery with its lifecycle
/// and exposes a deduplicated list of [DiscoveredServer].
class LanDiscoveryNotifier extends Notifier<LanDiscoveryState> {
  final List<Discovery> _discoveries = <Discovery>[];
  final Map<String, DiscoveredServer> _byKey = <String, DiscoveredServer>{};

  @override
  LanDiscoveryState build() {
    ref.onDispose(stop);
    return const LanDiscoveryState();
  }

  bool get _active => _discoveries.isNotEmpty;

  Future<void> start() async {
    if (_active) {
      return;
    }
    state = const LanDiscoveryState(searching: true);
    for (final type in _discoveryTypes) {
      await _startType(type);
    }
  }

  Future<void> _startType(String type) async {
    try {
      final discovery = await startDiscovery(
        type,
        autoResolve: true,
        ipLookupType: IpLookupType.v4,
      );
      _discoveries.add(discovery);
      discovery.addServiceListener((service, status) {
        _ingest(service, type, status);
      });
      for (final service in discovery.services) {
        _ingest(service, type, ServiceStatus.found);
      }
    } catch (error) {
      debugPrint('LAN discovery failed for $type: $error');
      state = state.copyWith(error: error.toString());
    }
  }

  void _ingest(Service service, String type, ServiceStatus status) {
    final host = service.host;
    final port = service.port;
    if (host == null || port == null) {
      return;
    }
    final key = '$type|$host:$port';
    if (status == ServiceStatus.lost) {
      _byKey.remove(key);
    } else {
      final rawName = service.name;
      final name = (rawName != null && rawName.isNotEmpty) ? rawName : host;
      _byKey[key] = DiscoveredServer(
        name: name,
        host: host,
        port: port,
        type: type,
      );
    }
    state = state.copyWith(servers: _byKey.values.toList());
  }

  /// Stops all discoveries and clears the result list.
  Future<void> stop() async {
    for (final discovery in _discoveries) {
      try {
        await stopDiscovery(discovery);
      } catch (_) {
        // Discovery may already be torn down by the platform.
      }
    }
    _discoveries.clear();
    _byKey.clear();
    if (ref.mounted) {
      state = const LanDiscoveryState();
    }
  }

  /// Convenience for the refresh button: restart from scratch.
  Future<void> restart() async {
    await stop();
    await start();
  }
}

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/core.freezed.dart';
part 'generated/core.g.dart';

@freezed
abstract class SetupParams with _$SetupParams {
  const factory SetupParams({
    @JsonKey(name: 'selected-map') required Map<String, String> selectedMap,
    @JsonKey(name: 'test-url') required String testUrl,
  }) = _SetupParams;

  factory SetupParams.fromJson(Map<String, dynamic> json) =>
      _$SetupParamsFromJson(json);
}

@freezed
abstract class UpdateParams with _$UpdateParams {
  const factory UpdateParams({
    required Tun tun,
    @JsonKey(name: 'mixed-port') required int mixedPort,
    @JsonKey(name: 'allow-lan') required bool allowLan,
    @JsonKey(
      name: 'find-process-mode',
      unknownEnumValue: FindProcessMode.always,
    )
    required FindProcessMode findProcessMode,
    @JsonKey(unknownEnumValue: Mode.rule) required Mode mode,
    @JsonKey(name: 'log-level', unknownEnumValue: LogLevel.error)
    required LogLevel logLevel,
    required bool ipv6,
    @JsonKey(name: 'tcp-concurrent') required bool tcpConcurrent,
    @JsonKey(name: 'external-controller') required String externalController,
    required String secret,
    @JsonKey(name: 'unified-delay') required bool unifiedDelay,
    @Default(false) @JsonKey(name: 'geo-auto-update') bool geoAutoUpdate,
    @Default(24) @JsonKey(name: 'geo-update-interval') int geoUpdateInterval,
  }) = _UpdateParams;

  factory UpdateParams.fromJson(Map<String, dynamic> json) =>
      _$UpdateParamsFromJson(json);
}

@freezed
abstract class VpnOptions with _$VpnOptions {
  const factory VpnOptions({
    required bool enable,
    required int port,
    required bool ipv6,
    required bool captureDns,
    required AccessControlProps accessControlProps,
    required bool allowBypass,
    required bool systemProxy,
    required bool suspendSupport,
    required List<String> bypassDomain,
    required String stack,
    @Default(defaultTunMtu) int mtu,
    @Default([]) List<String> routeAddress,
    @Default(false) bool disableIcmpForwarding,
    @Default(false) bool endpointIndependentNat,
    @Default(false) bool includeAllNetworks,
    @Default(true) bool excludeLocalNetworks,
    @Default(true) bool excludeAPNs,
    @Default(true) bool excludeCellularServices,
    @Default(false) bool enforceRoutes,
    @Default(true) bool excludeDeviceCommunication,
  }) = _VpnOptions;

  factory VpnOptions.fromJson(Map<String, Object?> json) =>
      _$VpnOptionsFromJson(json);
}

@freezed
abstract class InitParams with _$InitParams {
  const factory InitParams({
    @JsonKey(name: 'home-dir') required String homeDir,
    required int version,
  }) = _InitParams;

  factory InitParams.fromJson(Map<String, Object?> json) =>
      _$InitParamsFromJson(json);
}

@freezed
abstract class DeleteManagedPathParams with _$DeleteManagedPathParams {
  const factory DeleteManagedPathParams({
    required ManagedPathScope scope,
    @JsonKey(name: 'relative-path') required String relativePath,
  }) = _DeleteManagedPathParams;

  factory DeleteManagedPathParams.fromJson(Map<String, Object?> json) =>
      _$DeleteManagedPathParamsFromJson(json);
}

@freezed
abstract class ChangeProxyParams with _$ChangeProxyParams {
  const factory ChangeProxyParams({
    @JsonKey(name: 'group-name') required String groupName,
    @JsonKey(name: 'proxy-name') required String proxyName,
  }) = _ChangeProxyParams;

  factory ChangeProxyParams.fromJson(Map<String, Object?> json) =>
      _$ChangeProxyParamsFromJson(json);
}

@freezed
abstract class UpdateGeoDataParams with _$UpdateGeoDataParams {
  const factory UpdateGeoDataParams({
    @JsonKey(name: 'geo-type') required String geoType,
    @JsonKey(name: 'geo-name') required String geoName,
  }) = _UpdateGeoDataParams;

  factory UpdateGeoDataParams.fromJson(Map<String, Object?> json) =>
      _$UpdateGeoDataParamsFromJson(json);
}

@freezed
abstract class CoreEvent with _$CoreEvent {
  const factory CoreEvent({
    @JsonKey(unknownEnumValue: CoreEventType.crash) required CoreEventType type,
    dynamic data,
  }) = _CoreEvent;

  factory CoreEvent.fromJson(Map<String, Object?> json) =>
      _$CoreEventFromJson(json);
}

@freezed
abstract class InvokeMessage with _$InvokeMessage {
  const factory InvokeMessage({
    @JsonKey(unknownEnumValue: InvokeMessageType.process)
    required InvokeMessageType type,
    dynamic data,
  }) = _InvokeMessage;

  factory InvokeMessage.fromJson(Map<String, Object?> json) =>
      _$InvokeMessageFromJson(json);
}

@freezed
abstract class Delay with _$Delay {
  const factory Delay({required String name, required String url, int? value}) =
      _Delay;

  factory Delay.fromJson(Map<String, Object?> json) => _$DelayFromJson(json);
}

@freezed
abstract class Now with _$Now {
  const factory Now({required String name, required String value}) = _Now;

  factory Now.fromJson(Map<String, Object?> json) => _$NowFromJson(json);
}

@freezed
abstract class ProviderSubscriptionInfo with _$ProviderSubscriptionInfo {
  const factory ProviderSubscriptionInfo({
    @JsonKey(name: 'UPLOAD') @Default(0) int upload,
    @JsonKey(name: 'DOWNLOAD') @Default(0) int download,
    @JsonKey(name: 'TOTAL') @Default(0) int total,
    @JsonKey(name: 'EXPIRE') @Default(0) int expire,
  }) = _ProviderSubscriptionInfo;

  factory ProviderSubscriptionInfo.fromJson(Map<String, Object?> json) =>
      _$ProviderSubscriptionInfoFromJson(json);
}

SubscriptionInfo? subscriptionInfoFormCore(Map<String, Object?>? json) {
  if (json == null) return null;
  return SubscriptionInfo(
    upload: (json['Upload'] as num?)?.toInt() ?? 0,
    download: (json['Download'] as num?)?.toInt() ?? 0,
    total: (json['Total'] as num?)?.toInt() ?? 0,
    expire: (json['Expire'] as num?)?.toInt() ?? 0,
  );
}

@freezed
abstract class ExternalProvider with _$ExternalProvider {
  const factory ExternalProvider({
    required String name,
    required String type,
    String? format,
    String? path,
    required int count,
    @JsonKey(name: 'subscription-info', fromJson: subscriptionInfoFormCore)
    SubscriptionInfo? subscriptionInfo,
    @JsonKey(name: 'vehicle-type') required String vehicleType,
    @JsonKey(name: 'update-at') required DateTime updateAt,
  }) = _ExternalProvider;

  factory ExternalProvider.fromJson(Map<String, Object?> json) =>
      _$ExternalProviderFromJson(json);
}

extension ExternalProviderExt on ExternalProvider {
  String get updatingKey => 'provider_$name';

  bool get canEditAsText =>
      type != 'Rule' || format == 'YamlRule' || format == 'TextRule';
}

class TailscaleNode {
  final String id;
  final String publicKey;
  final String hostName;
  final String dnsName;
  final String os;
  final List<String> ips;
  final List<String> tags;
  final List<String> primaryRoutes;
  final List<String> endpoints;
  final String currentEndpoint;
  final String relay;
  final int rxBytes;
  final int txBytes;
  final bool online;
  final bool active;
  final bool self;
  final bool exitNode;
  final bool exitNodeOption;
  final bool expired;
  final DateTime? lastSeen;
  final DateTime? lastHandshake;
  final DateTime? keyExpiry;

  const TailscaleNode({
    required this.id,
    this.publicKey = '',
    required this.hostName,
    required this.dnsName,
    required this.os,
    required this.ips,
    this.tags = const [],
    this.primaryRoutes = const [],
    this.endpoints = const [],
    this.currentEndpoint = '',
    this.relay = '',
    this.rxBytes = 0,
    this.txBytes = 0,
    required this.online,
    required this.active,
    required this.self,
    required this.exitNode,
    required this.exitNodeOption,
    required this.expired,
    this.lastSeen,
    this.lastHandshake,
    this.keyExpiry,
  });

  factory TailscaleNode.fromJson(Map<String, Object?> json) {
    return TailscaleNode(
      id: json['id'] as String? ?? '',
      publicKey: json['public-key'] as String? ?? '',
      hostName: json['hostname'] as String? ?? '',
      dnsName: json['dns-name'] as String? ?? '',
      os: json['os'] as String? ?? '',
      ips: (json['ips'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      primaryRoutes: (json['primary-routes'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      endpoints: (json['endpoints'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      currentEndpoint: json['current-endpoint'] as String? ?? '',
      relay: json['relay'] as String? ?? '',
      rxBytes: json['rx-bytes'] as int? ?? 0,
      txBytes: json['tx-bytes'] as int? ?? 0,
      online: json['online'] as bool? ?? false,
      active: json['active'] as bool? ?? false,
      self: json['self'] as bool? ?? false,
      exitNode: json['exit-node'] as bool? ?? false,
      exitNodeOption: json['exit-node-option'] as bool? ?? false,
      expired: json['expired'] as bool? ?? false,
      lastSeen: DateTime.tryParse(json['last-seen'] as String? ?? ''),
      lastHandshake: DateTime.tryParse(json['last-handshake'] as String? ?? ''),
      keyExpiry: DateTime.tryParse(json['key-expiry'] as String? ?? ''),
    );
  }
}

class TailscaleNetworkDetails {
  final String magicDnsSuffix;
  final bool authKeyConfigured;
  final List<String> health;
  final List<TailscaleNode> nodes;

  const TailscaleNetworkDetails({
    this.magicDnsSuffix = '',
    this.authKeyConfigured = false,
    required this.health,
    required this.nodes,
  });

  factory TailscaleNetworkDetails.fromJson(Map<String, Object?> json) {
    return TailscaleNetworkDetails(
      magicDnsSuffix: json['magic-dns-suffix'] as String? ?? '',
      authKeyConfigured: json['auth-key-configured'] as bool? ?? false,
      health: (json['health'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      nodes: (json['nodes'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => TailscaleNode.fromJson(Map<String, Object?>.from(item)),
          )
          .toList(),
    );
  }
}

class ZeroTierPeer {
  final String address;
  final String role;
  final String version;
  final bool direct;
  final List<String> endpoints;
  final int latencyMs;

  const ZeroTierPeer({
    required this.address,
    required this.role,
    required this.version,
    required this.direct,
    required this.endpoints,
    required this.latencyMs,
  });

  factory ZeroTierPeer.fromJson(Map<String, Object?> json) {
    return ZeroTierPeer(
      address: json['address'] as String? ?? '',
      role: json['role'] as String? ?? '',
      version: json['version'] as String? ?? '',
      direct: json['direct'] as bool? ?? false,
      endpoints: (json['endpoints'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      latencyMs: json['latency-ms'] as int? ?? 0,
    );
  }
}

class ZeroTierNetworkDetails {
  final String networkId;
  final String node;
  final bool online;
  final List<String> addresses;
  final List<String> routes;
  final List<String> dns;
  final int mtu;
  final List<ZeroTierPeer> peers;

  const ZeroTierNetworkDetails({
    required this.networkId,
    required this.node,
    required this.online,
    required this.addresses,
    required this.routes,
    required this.dns,
    required this.mtu,
    required this.peers,
  });

  factory ZeroTierNetworkDetails.fromJson(Map<String, Object?> json) {
    return ZeroTierNetworkDetails(
      networkId: json['network-id'] as String? ?? '',
      node: json['node'] as String? ?? '',
      online: json['online'] as bool? ?? false,
      addresses: (json['addresses'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      routes: (json['routes'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      dns: (json['dns'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      mtu: json['mtu'] as int? ?? 0,
      peers: (json['peers'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => ZeroTierPeer.fromJson(Map<String, Object?>.from(item)))
          .toList(),
    );
  }
}

enum OverlayNetworkKind { tailscale, zerotier }

enum OverlayNetworkDetailLevel { summary, details }

enum OverlayNetworkState {
  uninitialized,
  starting,
  connected,
  needsLogin,
  needsApproval,
  stopped,
  error,
  unknown,
}

class OverlayNetworkTarget {
  final String name;
  final OverlayNetworkKind kind;
  final OverlayNetworkDetailLevel level;

  const OverlayNetworkTarget({
    required this.name,
    required this.kind,
    required this.level,
  });

  Map<String, Object?> toJson() {
    return {'name': name, 'kind': kind.name, 'level': level.name};
  }
}

class GetOverlayNetworkStatusParams {
  final List<OverlayNetworkTarget> targets;

  const GetOverlayNetworkStatusParams({required this.targets});

  Map<String, Object?> toJson() {
    return {'targets': targets.map((target) => target.toJson()).toList()};
  }
}

class TailscalePingResult {
  final int latencyMs;

  const TailscalePingResult({required this.latencyMs});

  factory TailscalePingResult.fromJson(Map<String, Object?> json) {
    return TailscalePingResult(latencyMs: json['latency-ms'] as int? ?? 0);
  }
}

class OverlayNetworkStatus {
  final String name;
  final OverlayNetworkKind kind;
  final OverlayNetworkState state;
  final String rawState;
  final String networkName;
  final String authUrl;
  final String error;
  final TailscaleNetworkDetails? tailscaleDetails;
  final ZeroTierNetworkDetails? zeroTierDetails;

  const OverlayNetworkStatus({
    required this.name,
    required this.kind,
    required this.state,
    required this.rawState,
    required this.networkName,
    required this.authUrl,
    required this.error,
    this.tailscaleDetails,
    this.zeroTierDetails,
  });

  bool get hasDetails => tailscaleDetails != null || zeroTierDetails != null;

  factory OverlayNetworkStatus.fromJson(Map<String, Object?> json) {
    final kind = switch (json['kind']) {
      'tailscale' => OverlayNetworkKind.tailscale,
      'zerotier' => OverlayNetworkKind.zerotier,
      _ => throw FormatException(
        'Unknown overlay network kind: ${json['kind']}',
      ),
    };
    final state = switch (json['state']) {
      'uninitialized' => OverlayNetworkState.uninitialized,
      'starting' => OverlayNetworkState.starting,
      'connected' => OverlayNetworkState.connected,
      'needs-login' => OverlayNetworkState.needsLogin,
      'needs-approval' => OverlayNetworkState.needsApproval,
      'stopped' => OverlayNetworkState.stopped,
      'error' => OverlayNetworkState.error,
      _ => OverlayNetworkState.unknown,
    };
    final details = json['details'];
    final detailsMap = details is Map
        ? Map<String, Object?>.from(details)
        : null;
    return OverlayNetworkStatus(
      name: json['name'] as String? ?? '',
      kind: kind,
      state: state,
      rawState: json['raw-state'] as String? ?? '',
      networkName: json['network-name'] as String? ?? '',
      authUrl: json['auth-url'] as String? ?? '',
      error: json['error'] as String? ?? '',
      tailscaleDetails:
          kind == OverlayNetworkKind.tailscale && detailsMap != null
          ? TailscaleNetworkDetails.fromJson(detailsMap)
          : null,
      zeroTierDetails: kind == OverlayNetworkKind.zerotier && detailsMap != null
          ? ZeroTierNetworkDetails.fromJson(detailsMap)
          : null,
    );
  }

  OverlayNetworkStatus retainDetailsFrom(OverlayNetworkStatus previous) {
    if (hasDetails || !previous.hasDetails || kind != previous.kind) {
      return this;
    }
    return OverlayNetworkStatus(
      name: name,
      kind: kind,
      state: state,
      rawState: rawState,
      networkName: networkName,
      authUrl: authUrl,
      error: error,
      tailscaleDetails: previous.tailscaleDetails,
      zeroTierDetails: previous.zeroTierDetails,
    );
  }
}

@freezed
abstract class ProxiesData with _$ProxiesData {
  const factory ProxiesData({
    required Map<String, dynamic> proxies,
    required List<String> all,
  }) = _ProxiesData;

  factory ProxiesData.fromJson(Map<String, Object?> json) =>
      _$ProxiesDataFromJson(json);
}

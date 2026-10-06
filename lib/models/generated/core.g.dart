// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../core.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RuleQueryParams _$RuleQueryParamsFromJson(Map<String, dynamic> json) =>
    _RuleQueryParams(
      target: json['target'] as String,
      port: (json['port'] as num?)?.toInt() ?? 443,
      network:
          $enumDecodeNullable(_$NetworkEnumMap, json['network']) ?? Network.tcp,
      sourceIP: json['sourceIP'] as String?,
      sourcePort: (json['sourcePort'] as num?)?.toInt(),
      destinationIP: json['destinationIP'] as String?,
      process: json['process'] as String?,
      processPath: json['processPath'] as String?,
      uid: (json['uid'] as num?)?.toInt(),
      inboundName: json['inboundName'] as String?,
      inboundUser: json['inboundUser'] as String?,
      sniffHost: json['sniffHost'] as String?,
      dscp: (json['dscp'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RuleQueryParamsToJson(_RuleQueryParams instance) =>
    <String, dynamic>{
      'target': instance.target,
      'port': instance.port,
      'network': _$NetworkEnumMap[instance.network]!,
      'sourceIP': ?instance.sourceIP,
      'sourcePort': ?instance.sourcePort,
      'destinationIP': ?instance.destinationIP,
      'process': ?instance.process,
      'processPath': ?instance.processPath,
      'uid': ?instance.uid,
      'inboundName': ?instance.inboundName,
      'inboundUser': ?instance.inboundUser,
      'sniffHost': ?instance.sniffHost,
      'dscp': ?instance.dscp,
    };

const _$NetworkEnumMap = {Network.tcp: 'tcp', Network.udp: 'udp'};

_RuleQuery _$RuleQueryFromJson(Map<String, dynamic> json) => _RuleQuery(
  target: json['target'] as String,
  port: (json['port'] as num).toInt(),
  network: $enumDecode(_$NetworkEnumMap, json['network']),
  mode: $enumDecode(_$ModeEnumMap, json['mode']),
  rule: json['rule'] as String,
  rulePayload: json['rulePayload'] as String,
  proxy: json['proxy'] as String,
  ip: json['ip'] as String,
  delay: (json['delay'] as num).toInt(),
);

Map<String, dynamic> _$RuleQueryToJson(_RuleQuery instance) =>
    <String, dynamic>{
      'target': instance.target,
      'port': instance.port,
      'network': _$NetworkEnumMap[instance.network]!,
      'mode': _$ModeEnumMap[instance.mode]!,
      'rule': instance.rule,
      'rulePayload': instance.rulePayload,
      'proxy': instance.proxy,
      'ip': instance.ip,
      'delay': instance.delay,
    };

const _$ModeEnumMap = {
  Mode.rule: 'rule',
  Mode.global: 'global',
  Mode.direct: 'direct',
};

_SetupParams _$SetupParamsFromJson(Map<String, dynamic> json) => _SetupParams(
  selectedMap: Map<String, String>.from(json['selected-map'] as Map),
  testUrl: json['test-url'] as String,
);

Map<String, dynamic> _$SetupParamsToJson(_SetupParams instance) =>
    <String, dynamic>{
      'selected-map': instance.selectedMap,
      'test-url': instance.testUrl,
    };

_UpdateParams _$UpdateParamsFromJson(Map<String, dynamic> json) =>
    _UpdateParams(
      tun: Tun.fromJson(json['tun'] as Map<String, dynamic>),
      mixedPort: (json['mixed-port'] as num).toInt(),
      allowLan: json['allow-lan'] as bool,
      findProcessMode: $enumDecode(
        _$FindProcessModeEnumMap,
        json['find-process-mode'],
      ),
      mode: $enumDecode(_$ModeEnumMap, json['mode']),
      logLevel: $enumDecode(_$LogLevelEnumMap, json['log-level']),
      ipv6: json['ipv6'] as bool,
      tcpConcurrent: json['tcp-concurrent'] as bool,
      externalController: json['external-controller'] as String,
      secret: json['secret'] as String,
      unifiedDelay: json['unified-delay'] as bool,
      authentication:
          (json['authentication'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      geoAutoUpdate: json['geo-auto-update'] as bool? ?? false,
      geoUpdateInterval: (json['geo-update-interval'] as num?)?.toInt() ?? 24,
    );

Map<String, dynamic> _$UpdateParamsToJson(_UpdateParams instance) =>
    <String, dynamic>{
      'tun': instance.tun,
      'mixed-port': instance.mixedPort,
      'allow-lan': instance.allowLan,
      'find-process-mode': _$FindProcessModeEnumMap[instance.findProcessMode]!,
      'mode': _$ModeEnumMap[instance.mode]!,
      'log-level': _$LogLevelEnumMap[instance.logLevel]!,
      'ipv6': instance.ipv6,
      'tcp-concurrent': instance.tcpConcurrent,
      'external-controller': instance.externalController,
      'secret': instance.secret,
      'unified-delay': instance.unifiedDelay,
      'authentication': instance.authentication,
      'geo-auto-update': instance.geoAutoUpdate,
      'geo-update-interval': instance.geoUpdateInterval,
    };

const _$FindProcessModeEnumMap = {
  FindProcessMode.always: 'always',
  FindProcessMode.off: 'off',
};

const _$LogLevelEnumMap = {
  LogLevel.debug: 'debug',
  LogLevel.info: 'info',
  LogLevel.warning: 'warning',
  LogLevel.error: 'error',
  LogLevel.silent: 'silent',
};

_VpnOptions _$VpnOptionsFromJson(Map<String, dynamic> json) => _VpnOptions(
  enable: json['enable'] as bool,
  port: (json['port'] as num).toInt(),
  ipv6: json['ipv6'] as bool,
  captureDns: json['captureDns'] as bool,
  accessControlProps: AccessControlProps.fromJson(
    json['accessControlProps'] as Map<String, dynamic>,
  ),
  allowBypass: json['allowBypass'] as bool,
  systemProxy: json['systemProxy'] as bool,
  suspendSupport: json['suspendSupport'] as bool,
  bypassDomain: (json['bypassDomain'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  stack: json['stack'] as String,
  mtu: (json['mtu'] as num?)?.toInt() ?? defaultTunMtu,
  routeAddress:
      (json['routeAddress'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  disableIcmpForwarding: json['disableIcmpForwarding'] as bool? ?? false,
  endpointIndependentNat: json['endpointIndependentNat'] as bool? ?? false,
  congestionController:
      $enumDecodeNullable(
        _$TunCongestionControllerEnumMap,
        json['congestionController'],
        unknownValue: TunCongestionController.cubic,
      ) ??
      TunCongestionController.cubic,
  recvMsgX: json['recvMsgX'] as bool? ?? true,
  sendMsgX: json['sendMsgX'] as bool? ?? true,
  includeAllNetworks: json['includeAllNetworks'] as bool? ?? false,
  excludeLocalNetworks: json['excludeLocalNetworks'] as bool? ?? true,
  excludeAPNs: json['excludeAPNs'] as bool? ?? true,
  excludeCellularServices: json['excludeCellularServices'] as bool? ?? true,
  enforceRoutes: json['enforceRoutes'] as bool? ?? false,
  excludeDeviceCommunication:
      json['excludeDeviceCommunication'] as bool? ?? true,
);

Map<String, dynamic> _$VpnOptionsToJson(_VpnOptions instance) =>
    <String, dynamic>{
      'enable': instance.enable,
      'port': instance.port,
      'ipv6': instance.ipv6,
      'captureDns': instance.captureDns,
      'accessControlProps': instance.accessControlProps,
      'allowBypass': instance.allowBypass,
      'systemProxy': instance.systemProxy,
      'suspendSupport': instance.suspendSupport,
      'bypassDomain': instance.bypassDomain,
      'stack': instance.stack,
      'mtu': instance.mtu,
      'routeAddress': instance.routeAddress,
      'disableIcmpForwarding': instance.disableIcmpForwarding,
      'endpointIndependentNat': instance.endpointIndependentNat,
      'congestionController':
          _$TunCongestionControllerEnumMap[instance.congestionController]!,
      'recvMsgX': instance.recvMsgX,
      'sendMsgX': instance.sendMsgX,
      'includeAllNetworks': instance.includeAllNetworks,
      'excludeLocalNetworks': instance.excludeLocalNetworks,
      'excludeAPNs': instance.excludeAPNs,
      'excludeCellularServices': instance.excludeCellularServices,
      'enforceRoutes': instance.enforceRoutes,
      'excludeDeviceCommunication': instance.excludeDeviceCommunication,
    };

const _$TunCongestionControllerEnumMap = {
  TunCongestionController.cubic: 'cubic',
  TunCongestionController.reno: 'reno',
  TunCongestionController.bbr: 'bbr',
  TunCongestionController.bbr3: 'bbr3',
};

_InitParams _$InitParamsFromJson(Map<String, dynamic> json) => _InitParams(
  homeDir: json['home-dir'] as String,
  version: (json['version'] as num).toInt(),
);

Map<String, dynamic> _$InitParamsToJson(_InitParams instance) =>
    <String, dynamic>{
      'home-dir': instance.homeDir,
      'version': instance.version,
    };

_DeleteManagedPathParams _$DeleteManagedPathParamsFromJson(
  Map<String, dynamic> json,
) => _DeleteManagedPathParams(
  scope: $enumDecode(_$ManagedPathScopeEnumMap, json['scope']),
  relativePath: json['relative-path'] as String,
);

Map<String, dynamic> _$DeleteManagedPathParamsToJson(
  _DeleteManagedPathParams instance,
) => <String, dynamic>{
  'scope': _$ManagedPathScopeEnumMap[instance.scope]!,
  'relative-path': instance.relativePath,
};

const _$ManagedPathScopeEnumMap = {
  ManagedPathScope.profiles: 'profiles',
  ManagedPathScope.providers: 'providers',
  ManagedPathScope.scripts: 'scripts',
};

_ChangeProxyParams _$ChangeProxyParamsFromJson(Map<String, dynamic> json) =>
    _ChangeProxyParams(
      groupName: json['group-name'] as String,
      proxyName: json['proxy-name'] as String,
    );

Map<String, dynamic> _$ChangeProxyParamsToJson(_ChangeProxyParams instance) =>
    <String, dynamic>{
      'group-name': instance.groupName,
      'proxy-name': instance.proxyName,
    };

_UpdateGeoDataParams _$UpdateGeoDataParamsFromJson(Map<String, dynamic> json) =>
    _UpdateGeoDataParams(
      geoType: json['geo-type'] as String,
      geoName: json['geo-name'] as String,
    );

Map<String, dynamic> _$UpdateGeoDataParamsToJson(
  _UpdateGeoDataParams instance,
) => <String, dynamic>{
  'geo-type': instance.geoType,
  'geo-name': instance.geoName,
};

_CoreEvent _$CoreEventFromJson(Map<String, dynamic> json) => _CoreEvent(
  type: $enumDecode(_$CoreEventTypeEnumMap, json['type']),
  data: json['data'],
);

Map<String, dynamic> _$CoreEventToJson(_CoreEvent instance) =>
    <String, dynamic>{
      'type': _$CoreEventTypeEnumMap[instance.type]!,
      'data': instance.data,
    };

const _$CoreEventTypeEnumMap = {
  CoreEventType.log: 'log',
  CoreEventType.delay: 'delay',
  CoreEventType.request: 'request',
  CoreEventType.dns: 'dns',
  CoreEventType.loaded: 'loaded',
  CoreEventType.crash: 'crash',
  CoreEventType.geoUpdate: 'geoUpdate',
};

_InvokeMessage _$InvokeMessageFromJson(Map<String, dynamic> json) =>
    _InvokeMessage(
      type: $enumDecode(_$InvokeMessageTypeEnumMap, json['type']),
      data: json['data'],
    );

Map<String, dynamic> _$InvokeMessageToJson(_InvokeMessage instance) =>
    <String, dynamic>{
      'type': _$InvokeMessageTypeEnumMap[instance.type]!,
      'data': instance.data,
    };

const _$InvokeMessageTypeEnumMap = {
  InvokeMessageType.protect: 'protect',
  InvokeMessageType.process: 'process',
};

_Delay _$DelayFromJson(Map<String, dynamic> json) => _Delay(
  name: json['name'] as String,
  url: json['url'] as String,
  value: (json['value'] as num?)?.toInt(),
);

Map<String, dynamic> _$DelayToJson(_Delay instance) => <String, dynamic>{
  'name': instance.name,
  'url': instance.url,
  'value': instance.value,
};

_Now _$NowFromJson(Map<String, dynamic> json) =>
    _Now(name: json['name'] as String, value: json['value'] as String);

Map<String, dynamic> _$NowToJson(_Now instance) => <String, dynamic>{
  'name': instance.name,
  'value': instance.value,
};

_ProviderSubscriptionInfo _$ProviderSubscriptionInfoFromJson(
  Map<String, dynamic> json,
) => _ProviderSubscriptionInfo(
  upload: (json['UPLOAD'] as num?)?.toInt() ?? 0,
  download: (json['DOWNLOAD'] as num?)?.toInt() ?? 0,
  total: (json['TOTAL'] as num?)?.toInt() ?? 0,
  expire: (json['EXPIRE'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ProviderSubscriptionInfoToJson(
  _ProviderSubscriptionInfo instance,
) => <String, dynamic>{
  'UPLOAD': instance.upload,
  'DOWNLOAD': instance.download,
  'TOTAL': instance.total,
  'EXPIRE': instance.expire,
};

_ExternalProvider _$ExternalProviderFromJson(Map<String, dynamic> json) =>
    _ExternalProvider(
      name: json['name'] as String,
      type: json['type'] as String,
      format: json['format'] as String?,
      path: json['path'] as String?,
      count: (json['count'] as num).toInt(),
      subscriptionInfo: subscriptionInfoFormCore(
        json['subscription-info'] as Map<String, Object?>?,
      ),
      vehicleType: json['vehicle-type'] as String,
      updateAt: DateTime.parse(json['update-at'] as String),
    );

Map<String, dynamic> _$ExternalProviderToJson(_ExternalProvider instance) =>
    <String, dynamic>{
      'name': instance.name,
      'type': instance.type,
      'format': instance.format,
      'path': instance.path,
      'count': instance.count,
      'subscription-info': instance.subscriptionInfo,
      'vehicle-type': instance.vehicleType,
      'update-at': instance.updateAt.toIso8601String(),
    };

_CoreRule _$CoreRuleFromJson(Map<String, dynamic> json) => _CoreRule(
  index: (json['index'] as num).toInt(),
  type: json['type'] as String,
  payload: json['payload'] as String? ?? '',
  proxy: json['proxy'] as String? ?? '',
  size: (json['size'] as num?)?.toInt() ?? -1,
  disabled: json['disabled'] as bool? ?? false,
  hitCount: (json['hitCount'] as num?)?.toInt() ?? 0,
  hitAt: json['hitAt'] == null ? null : DateTime.parse(json['hitAt'] as String),
  missCount: (json['missCount'] as num?)?.toInt() ?? 0,
  missAt: json['missAt'] == null
      ? null
      : DateTime.parse(json['missAt'] as String),
);

Map<String, dynamic> _$CoreRuleToJson(_CoreRule instance) => <String, dynamic>{
  'index': instance.index,
  'type': instance.type,
  'payload': instance.payload,
  'proxy': instance.proxy,
  'size': instance.size,
  'disabled': instance.disabled,
  'hitCount': instance.hitCount,
  'hitAt': instance.hitAt?.toIso8601String(),
  'missCount': instance.missCount,
  'missAt': instance.missAt?.toIso8601String(),
};

_SetRuleDisabledParams _$SetRuleDisabledParamsFromJson(
  Map<String, dynamic> json,
) => _SetRuleDisabledParams(
  index: (json['index'] as num).toInt(),
  type: json['type'] as String,
  payload: json['payload'] as String,
  disabled: json['disabled'] as bool,
);

Map<String, dynamic> _$SetRuleDisabledParamsToJson(
  _SetRuleDisabledParams instance,
) => <String, dynamic>{
  'index': instance.index,
  'type': instance.type,
  'payload': instance.payload,
  'disabled': instance.disabled,
};

_ProxiesData _$ProxiesDataFromJson(Map<String, dynamic> json) => _ProxiesData(
  proxies: json['proxies'] as Map<String, dynamic>,
  all: (json['all'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$ProxiesDataToJson(_ProxiesData instance) =>
    <String, dynamic>{'proxies': instance.proxies, 'all': instance.all};

_CoreMemoryInfo _$CoreMemoryInfoFromJson(Map<String, dynamic> json) =>
    _CoreMemoryInfo(
      sys: (json['sys'] as num?)?.toInt() ?? 0,
      heapObjects: (json['heapObjects'] as num?)?.toInt() ?? 0,
      heapUnused: (json['heapUnused'] as num?)?.toInt() ?? 0,
      heapIdle: (json['heapIdle'] as num?)?.toInt() ?? 0,
      heapReleased: (json['heapReleased'] as num?)?.toInt() ?? 0,
      stacks: (json['stacks'] as num?)?.toInt() ?? 0,
      metadata: (json['metadata'] as num?)?.toInt() ?? 0,
      gc: (json['gc'] as num?)?.toInt() ?? 0,
      other: (json['other'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CoreMemoryInfoToJson(_CoreMemoryInfo instance) =>
    <String, dynamic>{
      'sys': instance.sys,
      'heapObjects': instance.heapObjects,
      'heapUnused': instance.heapUnused,
      'heapIdle': instance.heapIdle,
      'heapReleased': instance.heapReleased,
      'stacks': instance.stacks,
      'metadata': instance.metadata,
      'gc': instance.gc,
      'other': instance.other,
    };

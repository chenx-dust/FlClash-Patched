// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SharedState _$SharedStateFromJson(Map<String, dynamic> json) => _SharedState(
  setupParams: json['setupParams'] == null
      ? null
      : SetupParams.fromJson(json['setupParams'] as Map<String, dynamic>),
  vpnOptions: json['vpnOptions'] == null
      ? null
      : VpnOptions.fromJson(json['vpnOptions'] as Map<String, dynamic>),
  currentProfileName: json['currentProfileName'] as String,
  onlyStatisticsProxy: json['onlyStatisticsProxy'] as bool,
  networkSpeedNotification: json['networkSpeedNotification'] as bool,
  alwaysOn: json['alwaysOn'] as bool? ?? false,
  excludeSSIDs:
      (json['excludeSSIDs'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$SharedStateToJson(_SharedState instance) =>
    <String, dynamic>{
      'setupParams': instance.setupParams,
      'vpnOptions': instance.vpnOptions,
      'currentProfileName': instance.currentProfileName,
      'onlyStatisticsProxy': instance.onlyStatisticsProxy,
      'networkSpeedNotification': instance.networkSpeedNotification,
      'alwaysOn': instance.alwaysOn,
      'excludeSSIDs': instance.excludeSSIDs,
    };

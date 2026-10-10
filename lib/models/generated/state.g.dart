// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WidgetColors _$WidgetColorsFromJson(Map<String, dynamic> json) =>
    _WidgetColors(
      background: (json['background'] as num).toInt(),
      onBackground: (json['onBackground'] as num).toInt(),
      onBackgroundVariant: (json['onBackgroundVariant'] as num).toInt(),
      primary: (json['primary'] as num).toInt(),
      onPrimary: (json['onPrimary'] as num).toInt(),
      trackOff: (json['trackOff'] as num).toInt(),
      thumbOff: (json['thumbOff'] as num).toInt(),
    );

Map<String, dynamic> _$WidgetColorsToJson(_WidgetColors instance) =>
    <String, dynamic>{
      'background': instance.background,
      'onBackground': instance.onBackground,
      'onBackgroundVariant': instance.onBackgroundVariant,
      'primary': instance.primary,
      'onPrimary': instance.onPrimary,
      'trackOff': instance.trackOff,
      'thumbOff': instance.thumbOff,
    };

_WidgetTheme _$WidgetThemeFromJson(Map<String, dynamic> json) => _WidgetTheme(
  themeMode: $enumDecode(_$ThemeModeEnumMap, json['themeMode']),
  light: WidgetColors.fromJson(json['light'] as Map<String, dynamic>),
  dark: WidgetColors.fromJson(json['dark'] as Map<String, dynamic>),
);

Map<String, dynamic> _$WidgetThemeToJson(_WidgetTheme instance) =>
    <String, dynamic>{
      'themeMode': _$ThemeModeEnumMap[instance.themeMode]!,
      'light': instance.light,
      'dark': instance.dark,
    };

const _$ThemeModeEnumMap = {
  ThemeMode.system: 'system',
  ThemeMode.light: 'light',
  ThemeMode.dark: 'dark',
};

_SharedState _$SharedStateFromJson(Map<String, dynamic> json) => _SharedState(
  setupParams: json['setupParams'] == null
      ? null
      : SetupParams.fromJson(json['setupParams'] as Map<String, dynamic>),
  vpnOptions: json['vpnOptions'] == null
      ? null
      : VpnOptions.fromJson(json['vpnOptions'] as Map<String, dynamic>),
  widgetTheme: json['widgetTheme'] == null
      ? null
      : WidgetTheme.fromJson(json['widgetTheme'] as Map<String, dynamic>),
  stopTip: json['stopTip'] as String,
  startTip: json['startTip'] as String,
  currentProfileName: json['currentProfileName'] as String,
  stopText: json['stopText'] as String,
  onlyStatisticsProxy: json['onlyStatisticsProxy'] as bool,
  showStopAction: json['showStopAction'] as bool? ?? true,
  networkSpeedNotification: json['networkSpeedNotification'] as bool? ?? false,
  collapseQuickSettingsPanel:
      json['collapseQuickSettingsPanel'] as bool? ?? true,
  showQuickSettingsProfileName:
      json['showQuickSettingsProfileName'] as bool? ?? true,
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
      'widgetTheme': instance.widgetTheme,
      'stopTip': instance.stopTip,
      'startTip': instance.startTip,
      'currentProfileName': instance.currentProfileName,
      'stopText': instance.stopText,
      'onlyStatisticsProxy': instance.onlyStatisticsProxy,
      'showStopAction': instance.showStopAction,
      'networkSpeedNotification': instance.networkSpeedNotification,
      'collapseQuickSettingsPanel': instance.collapseQuickSettingsPanel,
      'showQuickSettingsProfileName': instance.showQuickSettingsProfileName,
      'alwaysOn': instance.alwaysOn,
      'excludeSSIDs': instance.excludeSSIDs,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppSettingProps {

 String? get locale;@JsonKey(fromJson: dashboardWidgetsSafeFormJson) List<DashboardWidget> get dashboardWidgets; bool get onlyStatisticsProxy; bool get autoLaunch; bool get highPriorityAutoLaunch; bool get silentLaunch; bool get autoRun; bool get openLogs; bool get closeConnections; String get testUrl; bool get isAnimateToPage; bool get isSwipeToPage; bool get autoCheckUpdate; bool get showLabel; bool get disclaimerAccepted; bool get minimizeOnExit; bool get hidden; bool get developerMode;@JsonKey(unknownEnumValue: RestoreStrategy.compatible) RestoreStrategy get restoreStrategy; bool get showTrayTitle; String get customUserAgent; int get foregroundTickerInterval; bool get foregroundTickerIdleWhenUnfocused; int get foregroundTickerIdleInterval;
/// Create a copy of AppSettingProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppSettingPropsCopyWith<AppSettingProps> get copyWith => _$AppSettingPropsCopyWithImpl<AppSettingProps>(this as AppSettingProps, _$identity);

  /// Serializes this AppSettingProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppSettingProps&&(identical(other.locale, locale) || other.locale == locale)&&const DeepCollectionEquality().equals(other.dashboardWidgets, dashboardWidgets)&&(identical(other.onlyStatisticsProxy, onlyStatisticsProxy) || other.onlyStatisticsProxy == onlyStatisticsProxy)&&(identical(other.autoLaunch, autoLaunch) || other.autoLaunch == autoLaunch)&&(identical(other.highPriorityAutoLaunch, highPriorityAutoLaunch) || other.highPriorityAutoLaunch == highPriorityAutoLaunch)&&(identical(other.silentLaunch, silentLaunch) || other.silentLaunch == silentLaunch)&&(identical(other.autoRun, autoRun) || other.autoRun == autoRun)&&(identical(other.openLogs, openLogs) || other.openLogs == openLogs)&&(identical(other.closeConnections, closeConnections) || other.closeConnections == closeConnections)&&(identical(other.testUrl, testUrl) || other.testUrl == testUrl)&&(identical(other.isAnimateToPage, isAnimateToPage) || other.isAnimateToPage == isAnimateToPage)&&(identical(other.isSwipeToPage, isSwipeToPage) || other.isSwipeToPage == isSwipeToPage)&&(identical(other.autoCheckUpdate, autoCheckUpdate) || other.autoCheckUpdate == autoCheckUpdate)&&(identical(other.showLabel, showLabel) || other.showLabel == showLabel)&&(identical(other.disclaimerAccepted, disclaimerAccepted) || other.disclaimerAccepted == disclaimerAccepted)&&(identical(other.minimizeOnExit, minimizeOnExit) || other.minimizeOnExit == minimizeOnExit)&&(identical(other.hidden, hidden) || other.hidden == hidden)&&(identical(other.developerMode, developerMode) || other.developerMode == developerMode)&&(identical(other.restoreStrategy, restoreStrategy) || other.restoreStrategy == restoreStrategy)&&(identical(other.showTrayTitle, showTrayTitle) || other.showTrayTitle == showTrayTitle)&&(identical(other.customUserAgent, customUserAgent) || other.customUserAgent == customUserAgent)&&(identical(other.foregroundTickerInterval, foregroundTickerInterval) || other.foregroundTickerInterval == foregroundTickerInterval)&&(identical(other.foregroundTickerIdleWhenUnfocused, foregroundTickerIdleWhenUnfocused) || other.foregroundTickerIdleWhenUnfocused == foregroundTickerIdleWhenUnfocused)&&(identical(other.foregroundTickerIdleInterval, foregroundTickerIdleInterval) || other.foregroundTickerIdleInterval == foregroundTickerIdleInterval));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,locale,const DeepCollectionEquality().hash(dashboardWidgets),onlyStatisticsProxy,autoLaunch,highPriorityAutoLaunch,silentLaunch,autoRun,openLogs,closeConnections,testUrl,isAnimateToPage,isSwipeToPage,autoCheckUpdate,showLabel,disclaimerAccepted,minimizeOnExit,hidden,developerMode,restoreStrategy,showTrayTitle,customUserAgent,foregroundTickerInterval,foregroundTickerIdleWhenUnfocused,foregroundTickerIdleInterval]);

@override
String toString() {
  return 'AppSettingProps(locale: $locale, dashboardWidgets: $dashboardWidgets, onlyStatisticsProxy: $onlyStatisticsProxy, autoLaunch: $autoLaunch, highPriorityAutoLaunch: $highPriorityAutoLaunch, silentLaunch: $silentLaunch, autoRun: $autoRun, openLogs: $openLogs, closeConnections: $closeConnections, testUrl: $testUrl, isAnimateToPage: $isAnimateToPage, isSwipeToPage: $isSwipeToPage, autoCheckUpdate: $autoCheckUpdate, showLabel: $showLabel, disclaimerAccepted: $disclaimerAccepted, minimizeOnExit: $minimizeOnExit, hidden: $hidden, developerMode: $developerMode, restoreStrategy: $restoreStrategy, showTrayTitle: $showTrayTitle, customUserAgent: $customUserAgent, foregroundTickerInterval: $foregroundTickerInterval, foregroundTickerIdleWhenUnfocused: $foregroundTickerIdleWhenUnfocused, foregroundTickerIdleInterval: $foregroundTickerIdleInterval)';
}


}

/// @nodoc
abstract mixin class $AppSettingPropsCopyWith<$Res>  {
  factory $AppSettingPropsCopyWith(AppSettingProps value, $Res Function(AppSettingProps) _then) = _$AppSettingPropsCopyWithImpl;
@useResult
$Res call({
 String? locale,@JsonKey(fromJson: dashboardWidgetsSafeFormJson) List<DashboardWidget> dashboardWidgets, bool onlyStatisticsProxy, bool autoLaunch, bool highPriorityAutoLaunch, bool silentLaunch, bool autoRun, bool openLogs, bool closeConnections, String testUrl, bool isAnimateToPage, bool isSwipeToPage, bool autoCheckUpdate, bool showLabel, bool disclaimerAccepted, bool minimizeOnExit, bool hidden, bool developerMode,@JsonKey(unknownEnumValue: RestoreStrategy.compatible) RestoreStrategy restoreStrategy, bool showTrayTitle, String customUserAgent, int foregroundTickerInterval, bool foregroundTickerIdleWhenUnfocused, int foregroundTickerIdleInterval
});




}
/// @nodoc
class _$AppSettingPropsCopyWithImpl<$Res>
    implements $AppSettingPropsCopyWith<$Res> {
  _$AppSettingPropsCopyWithImpl(this._self, this._then);

  final AppSettingProps _self;
  final $Res Function(AppSettingProps) _then;

/// Create a copy of AppSettingProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? locale = freezed,Object? dashboardWidgets = null,Object? onlyStatisticsProxy = null,Object? autoLaunch = null,Object? highPriorityAutoLaunch = null,Object? silentLaunch = null,Object? autoRun = null,Object? openLogs = null,Object? closeConnections = null,Object? testUrl = null,Object? isAnimateToPage = null,Object? isSwipeToPage = null,Object? autoCheckUpdate = null,Object? showLabel = null,Object? disclaimerAccepted = null,Object? minimizeOnExit = null,Object? hidden = null,Object? developerMode = null,Object? restoreStrategy = null,Object? showTrayTitle = null,Object? customUserAgent = null,Object? foregroundTickerInterval = null,Object? foregroundTickerIdleWhenUnfocused = null,Object? foregroundTickerIdleInterval = null,}) {
  return _then(_self.copyWith(
locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String?,dashboardWidgets: null == dashboardWidgets ? _self.dashboardWidgets : dashboardWidgets // ignore: cast_nullable_to_non_nullable
as List<DashboardWidget>,onlyStatisticsProxy: null == onlyStatisticsProxy ? _self.onlyStatisticsProxy : onlyStatisticsProxy // ignore: cast_nullable_to_non_nullable
as bool,autoLaunch: null == autoLaunch ? _self.autoLaunch : autoLaunch // ignore: cast_nullable_to_non_nullable
as bool,highPriorityAutoLaunch: null == highPriorityAutoLaunch ? _self.highPriorityAutoLaunch : highPriorityAutoLaunch // ignore: cast_nullable_to_non_nullable
as bool,silentLaunch: null == silentLaunch ? _self.silentLaunch : silentLaunch // ignore: cast_nullable_to_non_nullable
as bool,autoRun: null == autoRun ? _self.autoRun : autoRun // ignore: cast_nullable_to_non_nullable
as bool,openLogs: null == openLogs ? _self.openLogs : openLogs // ignore: cast_nullable_to_non_nullable
as bool,closeConnections: null == closeConnections ? _self.closeConnections : closeConnections // ignore: cast_nullable_to_non_nullable
as bool,testUrl: null == testUrl ? _self.testUrl : testUrl // ignore: cast_nullable_to_non_nullable
as String,isAnimateToPage: null == isAnimateToPage ? _self.isAnimateToPage : isAnimateToPage // ignore: cast_nullable_to_non_nullable
as bool,isSwipeToPage: null == isSwipeToPage ? _self.isSwipeToPage : isSwipeToPage // ignore: cast_nullable_to_non_nullable
as bool,autoCheckUpdate: null == autoCheckUpdate ? _self.autoCheckUpdate : autoCheckUpdate // ignore: cast_nullable_to_non_nullable
as bool,showLabel: null == showLabel ? _self.showLabel : showLabel // ignore: cast_nullable_to_non_nullable
as bool,disclaimerAccepted: null == disclaimerAccepted ? _self.disclaimerAccepted : disclaimerAccepted // ignore: cast_nullable_to_non_nullable
as bool,minimizeOnExit: null == minimizeOnExit ? _self.minimizeOnExit : minimizeOnExit // ignore: cast_nullable_to_non_nullable
as bool,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,developerMode: null == developerMode ? _self.developerMode : developerMode // ignore: cast_nullable_to_non_nullable
as bool,restoreStrategy: null == restoreStrategy ? _self.restoreStrategy : restoreStrategy // ignore: cast_nullable_to_non_nullable
as RestoreStrategy,showTrayTitle: null == showTrayTitle ? _self.showTrayTitle : showTrayTitle // ignore: cast_nullable_to_non_nullable
as bool,customUserAgent: null == customUserAgent ? _self.customUserAgent : customUserAgent // ignore: cast_nullable_to_non_nullable
as String,foregroundTickerInterval: null == foregroundTickerInterval ? _self.foregroundTickerInterval : foregroundTickerInterval // ignore: cast_nullable_to_non_nullable
as int,foregroundTickerIdleWhenUnfocused: null == foregroundTickerIdleWhenUnfocused ? _self.foregroundTickerIdleWhenUnfocused : foregroundTickerIdleWhenUnfocused // ignore: cast_nullable_to_non_nullable
as bool,foregroundTickerIdleInterval: null == foregroundTickerIdleInterval ? _self.foregroundTickerIdleInterval : foregroundTickerIdleInterval // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AppSettingProps].
extension AppSettingPropsPatterns on AppSettingProps {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppSettingProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppSettingProps() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppSettingProps value)  $default,){
final _that = this;
switch (_that) {
case _AppSettingProps():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppSettingProps value)?  $default,){
final _that = this;
switch (_that) {
case _AppSettingProps() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? locale, @JsonKey(fromJson: dashboardWidgetsSafeFormJson)  List<DashboardWidget> dashboardWidgets,  bool onlyStatisticsProxy,  bool autoLaunch,  bool highPriorityAutoLaunch,  bool silentLaunch,  bool autoRun,  bool openLogs,  bool closeConnections,  String testUrl,  bool isAnimateToPage,  bool isSwipeToPage,  bool autoCheckUpdate,  bool showLabel,  bool disclaimerAccepted,  bool minimizeOnExit,  bool hidden,  bool developerMode, @JsonKey(unknownEnumValue: RestoreStrategy.compatible)  RestoreStrategy restoreStrategy,  bool showTrayTitle,  String customUserAgent,  int foregroundTickerInterval,  bool foregroundTickerIdleWhenUnfocused,  int foregroundTickerIdleInterval)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppSettingProps() when $default != null:
return $default(_that.locale,_that.dashboardWidgets,_that.onlyStatisticsProxy,_that.autoLaunch,_that.highPriorityAutoLaunch,_that.silentLaunch,_that.autoRun,_that.openLogs,_that.closeConnections,_that.testUrl,_that.isAnimateToPage,_that.isSwipeToPage,_that.autoCheckUpdate,_that.showLabel,_that.disclaimerAccepted,_that.minimizeOnExit,_that.hidden,_that.developerMode,_that.restoreStrategy,_that.showTrayTitle,_that.customUserAgent,_that.foregroundTickerInterval,_that.foregroundTickerIdleWhenUnfocused,_that.foregroundTickerIdleInterval);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? locale, @JsonKey(fromJson: dashboardWidgetsSafeFormJson)  List<DashboardWidget> dashboardWidgets,  bool onlyStatisticsProxy,  bool autoLaunch,  bool highPriorityAutoLaunch,  bool silentLaunch,  bool autoRun,  bool openLogs,  bool closeConnections,  String testUrl,  bool isAnimateToPage,  bool isSwipeToPage,  bool autoCheckUpdate,  bool showLabel,  bool disclaimerAccepted,  bool minimizeOnExit,  bool hidden,  bool developerMode, @JsonKey(unknownEnumValue: RestoreStrategy.compatible)  RestoreStrategy restoreStrategy,  bool showTrayTitle,  String customUserAgent,  int foregroundTickerInterval,  bool foregroundTickerIdleWhenUnfocused,  int foregroundTickerIdleInterval)  $default,) {final _that = this;
switch (_that) {
case _AppSettingProps():
return $default(_that.locale,_that.dashboardWidgets,_that.onlyStatisticsProxy,_that.autoLaunch,_that.highPriorityAutoLaunch,_that.silentLaunch,_that.autoRun,_that.openLogs,_that.closeConnections,_that.testUrl,_that.isAnimateToPage,_that.isSwipeToPage,_that.autoCheckUpdate,_that.showLabel,_that.disclaimerAccepted,_that.minimizeOnExit,_that.hidden,_that.developerMode,_that.restoreStrategy,_that.showTrayTitle,_that.customUserAgent,_that.foregroundTickerInterval,_that.foregroundTickerIdleWhenUnfocused,_that.foregroundTickerIdleInterval);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? locale, @JsonKey(fromJson: dashboardWidgetsSafeFormJson)  List<DashboardWidget> dashboardWidgets,  bool onlyStatisticsProxy,  bool autoLaunch,  bool highPriorityAutoLaunch,  bool silentLaunch,  bool autoRun,  bool openLogs,  bool closeConnections,  String testUrl,  bool isAnimateToPage,  bool isSwipeToPage,  bool autoCheckUpdate,  bool showLabel,  bool disclaimerAccepted,  bool minimizeOnExit,  bool hidden,  bool developerMode, @JsonKey(unknownEnumValue: RestoreStrategy.compatible)  RestoreStrategy restoreStrategy,  bool showTrayTitle,  String customUserAgent,  int foregroundTickerInterval,  bool foregroundTickerIdleWhenUnfocused,  int foregroundTickerIdleInterval)?  $default,) {final _that = this;
switch (_that) {
case _AppSettingProps() when $default != null:
return $default(_that.locale,_that.dashboardWidgets,_that.onlyStatisticsProxy,_that.autoLaunch,_that.highPriorityAutoLaunch,_that.silentLaunch,_that.autoRun,_that.openLogs,_that.closeConnections,_that.testUrl,_that.isAnimateToPage,_that.isSwipeToPage,_that.autoCheckUpdate,_that.showLabel,_that.disclaimerAccepted,_that.minimizeOnExit,_that.hidden,_that.developerMode,_that.restoreStrategy,_that.showTrayTitle,_that.customUserAgent,_that.foregroundTickerInterval,_that.foregroundTickerIdleWhenUnfocused,_that.foregroundTickerIdleInterval);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppSettingProps implements AppSettingProps {
  const _AppSettingProps({this.locale, @JsonKey(fromJson: dashboardWidgetsSafeFormJson) final  List<DashboardWidget> dashboardWidgets = defaultDashboardWidgets, this.onlyStatisticsProxy = false, this.autoLaunch = false, this.highPriorityAutoLaunch = false, this.silentLaunch = false, this.autoRun = false, this.openLogs = false, this.closeConnections = true, this.testUrl = defaultTestUrl, this.isAnimateToPage = true, this.isSwipeToPage = true, this.autoCheckUpdate = true, this.showLabel = false, this.disclaimerAccepted = false, this.minimizeOnExit = true, this.hidden = false, this.developerMode = false, @JsonKey(unknownEnumValue: RestoreStrategy.compatible) this.restoreStrategy = RestoreStrategy.compatible, this.showTrayTitle = true, this.customUserAgent = '', this.foregroundTickerInterval = defaultForegroundTickerInterval, this.foregroundTickerIdleWhenUnfocused = true, this.foregroundTickerIdleInterval = defaultForegroundTickerIdleInterval}): _dashboardWidgets = dashboardWidgets;
  factory _AppSettingProps.fromJson(Map<String, dynamic> json) => _$AppSettingPropsFromJson(json);

@override final  String? locale;
 final  List<DashboardWidget> _dashboardWidgets;
@override@JsonKey(fromJson: dashboardWidgetsSafeFormJson) List<DashboardWidget> get dashboardWidgets {
  if (_dashboardWidgets is EqualUnmodifiableListView) return _dashboardWidgets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dashboardWidgets);
}

@override@JsonKey() final  bool onlyStatisticsProxy;
@override@JsonKey() final  bool autoLaunch;
@override@JsonKey() final  bool highPriorityAutoLaunch;
@override@JsonKey() final  bool silentLaunch;
@override@JsonKey() final  bool autoRun;
@override@JsonKey() final  bool openLogs;
@override@JsonKey() final  bool closeConnections;
@override@JsonKey() final  String testUrl;
@override@JsonKey() final  bool isAnimateToPage;
@override@JsonKey() final  bool isSwipeToPage;
@override@JsonKey() final  bool autoCheckUpdate;
@override@JsonKey() final  bool showLabel;
@override@JsonKey() final  bool disclaimerAccepted;
@override@JsonKey() final  bool minimizeOnExit;
@override@JsonKey() final  bool hidden;
@override@JsonKey() final  bool developerMode;
@override@JsonKey(unknownEnumValue: RestoreStrategy.compatible) final  RestoreStrategy restoreStrategy;
@override@JsonKey() final  bool showTrayTitle;
@override@JsonKey() final  String customUserAgent;
@override@JsonKey() final  int foregroundTickerInterval;
@override@JsonKey() final  bool foregroundTickerIdleWhenUnfocused;
@override@JsonKey() final  int foregroundTickerIdleInterval;

/// Create a copy of AppSettingProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppSettingPropsCopyWith<_AppSettingProps> get copyWith => __$AppSettingPropsCopyWithImpl<_AppSettingProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppSettingPropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppSettingProps&&(identical(other.locale, locale) || other.locale == locale)&&const DeepCollectionEquality().equals(other._dashboardWidgets, _dashboardWidgets)&&(identical(other.onlyStatisticsProxy, onlyStatisticsProxy) || other.onlyStatisticsProxy == onlyStatisticsProxy)&&(identical(other.autoLaunch, autoLaunch) || other.autoLaunch == autoLaunch)&&(identical(other.highPriorityAutoLaunch, highPriorityAutoLaunch) || other.highPriorityAutoLaunch == highPriorityAutoLaunch)&&(identical(other.silentLaunch, silentLaunch) || other.silentLaunch == silentLaunch)&&(identical(other.autoRun, autoRun) || other.autoRun == autoRun)&&(identical(other.openLogs, openLogs) || other.openLogs == openLogs)&&(identical(other.closeConnections, closeConnections) || other.closeConnections == closeConnections)&&(identical(other.testUrl, testUrl) || other.testUrl == testUrl)&&(identical(other.isAnimateToPage, isAnimateToPage) || other.isAnimateToPage == isAnimateToPage)&&(identical(other.isSwipeToPage, isSwipeToPage) || other.isSwipeToPage == isSwipeToPage)&&(identical(other.autoCheckUpdate, autoCheckUpdate) || other.autoCheckUpdate == autoCheckUpdate)&&(identical(other.showLabel, showLabel) || other.showLabel == showLabel)&&(identical(other.disclaimerAccepted, disclaimerAccepted) || other.disclaimerAccepted == disclaimerAccepted)&&(identical(other.minimizeOnExit, minimizeOnExit) || other.minimizeOnExit == minimizeOnExit)&&(identical(other.hidden, hidden) || other.hidden == hidden)&&(identical(other.developerMode, developerMode) || other.developerMode == developerMode)&&(identical(other.restoreStrategy, restoreStrategy) || other.restoreStrategy == restoreStrategy)&&(identical(other.showTrayTitle, showTrayTitle) || other.showTrayTitle == showTrayTitle)&&(identical(other.customUserAgent, customUserAgent) || other.customUserAgent == customUserAgent)&&(identical(other.foregroundTickerInterval, foregroundTickerInterval) || other.foregroundTickerInterval == foregroundTickerInterval)&&(identical(other.foregroundTickerIdleWhenUnfocused, foregroundTickerIdleWhenUnfocused) || other.foregroundTickerIdleWhenUnfocused == foregroundTickerIdleWhenUnfocused)&&(identical(other.foregroundTickerIdleInterval, foregroundTickerIdleInterval) || other.foregroundTickerIdleInterval == foregroundTickerIdleInterval));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,locale,const DeepCollectionEquality().hash(_dashboardWidgets),onlyStatisticsProxy,autoLaunch,highPriorityAutoLaunch,silentLaunch,autoRun,openLogs,closeConnections,testUrl,isAnimateToPage,isSwipeToPage,autoCheckUpdate,showLabel,disclaimerAccepted,minimizeOnExit,hidden,developerMode,restoreStrategy,showTrayTitle,customUserAgent,foregroundTickerInterval,foregroundTickerIdleWhenUnfocused,foregroundTickerIdleInterval]);

@override
String toString() {
  return 'AppSettingProps(locale: $locale, dashboardWidgets: $dashboardWidgets, onlyStatisticsProxy: $onlyStatisticsProxy, autoLaunch: $autoLaunch, highPriorityAutoLaunch: $highPriorityAutoLaunch, silentLaunch: $silentLaunch, autoRun: $autoRun, openLogs: $openLogs, closeConnections: $closeConnections, testUrl: $testUrl, isAnimateToPage: $isAnimateToPage, isSwipeToPage: $isSwipeToPage, autoCheckUpdate: $autoCheckUpdate, showLabel: $showLabel, disclaimerAccepted: $disclaimerAccepted, minimizeOnExit: $minimizeOnExit, hidden: $hidden, developerMode: $developerMode, restoreStrategy: $restoreStrategy, showTrayTitle: $showTrayTitle, customUserAgent: $customUserAgent, foregroundTickerInterval: $foregroundTickerInterval, foregroundTickerIdleWhenUnfocused: $foregroundTickerIdleWhenUnfocused, foregroundTickerIdleInterval: $foregroundTickerIdleInterval)';
}


}

/// @nodoc
abstract mixin class _$AppSettingPropsCopyWith<$Res> implements $AppSettingPropsCopyWith<$Res> {
  factory _$AppSettingPropsCopyWith(_AppSettingProps value, $Res Function(_AppSettingProps) _then) = __$AppSettingPropsCopyWithImpl;
@override @useResult
$Res call({
 String? locale,@JsonKey(fromJson: dashboardWidgetsSafeFormJson) List<DashboardWidget> dashboardWidgets, bool onlyStatisticsProxy, bool autoLaunch, bool highPriorityAutoLaunch, bool silentLaunch, bool autoRun, bool openLogs, bool closeConnections, String testUrl, bool isAnimateToPage, bool isSwipeToPage, bool autoCheckUpdate, bool showLabel, bool disclaimerAccepted, bool minimizeOnExit, bool hidden, bool developerMode,@JsonKey(unknownEnumValue: RestoreStrategy.compatible) RestoreStrategy restoreStrategy, bool showTrayTitle, String customUserAgent, int foregroundTickerInterval, bool foregroundTickerIdleWhenUnfocused, int foregroundTickerIdleInterval
});




}
/// @nodoc
class __$AppSettingPropsCopyWithImpl<$Res>
    implements _$AppSettingPropsCopyWith<$Res> {
  __$AppSettingPropsCopyWithImpl(this._self, this._then);

  final _AppSettingProps _self;
  final $Res Function(_AppSettingProps) _then;

/// Create a copy of AppSettingProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? locale = freezed,Object? dashboardWidgets = null,Object? onlyStatisticsProxy = null,Object? autoLaunch = null,Object? highPriorityAutoLaunch = null,Object? silentLaunch = null,Object? autoRun = null,Object? openLogs = null,Object? closeConnections = null,Object? testUrl = null,Object? isAnimateToPage = null,Object? isSwipeToPage = null,Object? autoCheckUpdate = null,Object? showLabel = null,Object? disclaimerAccepted = null,Object? minimizeOnExit = null,Object? hidden = null,Object? developerMode = null,Object? restoreStrategy = null,Object? showTrayTitle = null,Object? customUserAgent = null,Object? foregroundTickerInterval = null,Object? foregroundTickerIdleWhenUnfocused = null,Object? foregroundTickerIdleInterval = null,}) {
  return _then(_AppSettingProps(
locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String?,dashboardWidgets: null == dashboardWidgets ? _self._dashboardWidgets : dashboardWidgets // ignore: cast_nullable_to_non_nullable
as List<DashboardWidget>,onlyStatisticsProxy: null == onlyStatisticsProxy ? _self.onlyStatisticsProxy : onlyStatisticsProxy // ignore: cast_nullable_to_non_nullable
as bool,autoLaunch: null == autoLaunch ? _self.autoLaunch : autoLaunch // ignore: cast_nullable_to_non_nullable
as bool,highPriorityAutoLaunch: null == highPriorityAutoLaunch ? _self.highPriorityAutoLaunch : highPriorityAutoLaunch // ignore: cast_nullable_to_non_nullable
as bool,silentLaunch: null == silentLaunch ? _self.silentLaunch : silentLaunch // ignore: cast_nullable_to_non_nullable
as bool,autoRun: null == autoRun ? _self.autoRun : autoRun // ignore: cast_nullable_to_non_nullable
as bool,openLogs: null == openLogs ? _self.openLogs : openLogs // ignore: cast_nullable_to_non_nullable
as bool,closeConnections: null == closeConnections ? _self.closeConnections : closeConnections // ignore: cast_nullable_to_non_nullable
as bool,testUrl: null == testUrl ? _self.testUrl : testUrl // ignore: cast_nullable_to_non_nullable
as String,isAnimateToPage: null == isAnimateToPage ? _self.isAnimateToPage : isAnimateToPage // ignore: cast_nullable_to_non_nullable
as bool,isSwipeToPage: null == isSwipeToPage ? _self.isSwipeToPage : isSwipeToPage // ignore: cast_nullable_to_non_nullable
as bool,autoCheckUpdate: null == autoCheckUpdate ? _self.autoCheckUpdate : autoCheckUpdate // ignore: cast_nullable_to_non_nullable
as bool,showLabel: null == showLabel ? _self.showLabel : showLabel // ignore: cast_nullable_to_non_nullable
as bool,disclaimerAccepted: null == disclaimerAccepted ? _self.disclaimerAccepted : disclaimerAccepted // ignore: cast_nullable_to_non_nullable
as bool,minimizeOnExit: null == minimizeOnExit ? _self.minimizeOnExit : minimizeOnExit // ignore: cast_nullable_to_non_nullable
as bool,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,developerMode: null == developerMode ? _self.developerMode : developerMode // ignore: cast_nullable_to_non_nullable
as bool,restoreStrategy: null == restoreStrategy ? _self.restoreStrategy : restoreStrategy // ignore: cast_nullable_to_non_nullable
as RestoreStrategy,showTrayTitle: null == showTrayTitle ? _self.showTrayTitle : showTrayTitle // ignore: cast_nullable_to_non_nullable
as bool,customUserAgent: null == customUserAgent ? _self.customUserAgent : customUserAgent // ignore: cast_nullable_to_non_nullable
as String,foregroundTickerInterval: null == foregroundTickerInterval ? _self.foregroundTickerInterval : foregroundTickerInterval // ignore: cast_nullable_to_non_nullable
as int,foregroundTickerIdleWhenUnfocused: null == foregroundTickerIdleWhenUnfocused ? _self.foregroundTickerIdleWhenUnfocused : foregroundTickerIdleWhenUnfocused // ignore: cast_nullable_to_non_nullable
as bool,foregroundTickerIdleInterval: null == foregroundTickerIdleInterval ? _self.foregroundTickerIdleInterval : foregroundTickerIdleInterval // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$AccessControlProps {

 bool get enable;@JsonKey(unknownEnumValue: AccessControlMode.rejectSelected) AccessControlMode get mode; List<String> get acceptList; List<String> get rejectList;@JsonKey(unknownEnumValue: AccessSortType.none) AccessSortType get sort; bool get isFilterSystemApp; bool get isFilterNonInternetApp;
/// Create a copy of AccessControlProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccessControlPropsCopyWith<AccessControlProps> get copyWith => _$AccessControlPropsCopyWithImpl<AccessControlProps>(this as AccessControlProps, _$identity);

  /// Serializes this AccessControlProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccessControlProps&&(identical(other.enable, enable) || other.enable == enable)&&(identical(other.mode, mode) || other.mode == mode)&&const DeepCollectionEquality().equals(other.acceptList, acceptList)&&const DeepCollectionEquality().equals(other.rejectList, rejectList)&&(identical(other.sort, sort) || other.sort == sort)&&(identical(other.isFilterSystemApp, isFilterSystemApp) || other.isFilterSystemApp == isFilterSystemApp)&&(identical(other.isFilterNonInternetApp, isFilterNonInternetApp) || other.isFilterNonInternetApp == isFilterNonInternetApp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enable,mode,const DeepCollectionEquality().hash(acceptList),const DeepCollectionEquality().hash(rejectList),sort,isFilterSystemApp,isFilterNonInternetApp);

@override
String toString() {
  return 'AccessControlProps(enable: $enable, mode: $mode, acceptList: $acceptList, rejectList: $rejectList, sort: $sort, isFilterSystemApp: $isFilterSystemApp, isFilterNonInternetApp: $isFilterNonInternetApp)';
}


}

/// @nodoc
abstract mixin class $AccessControlPropsCopyWith<$Res>  {
  factory $AccessControlPropsCopyWith(AccessControlProps value, $Res Function(AccessControlProps) _then) = _$AccessControlPropsCopyWithImpl;
@useResult
$Res call({
 bool enable,@JsonKey(unknownEnumValue: AccessControlMode.rejectSelected) AccessControlMode mode, List<String> acceptList, List<String> rejectList,@JsonKey(unknownEnumValue: AccessSortType.none) AccessSortType sort, bool isFilterSystemApp, bool isFilterNonInternetApp
});




}
/// @nodoc
class _$AccessControlPropsCopyWithImpl<$Res>
    implements $AccessControlPropsCopyWith<$Res> {
  _$AccessControlPropsCopyWithImpl(this._self, this._then);

  final AccessControlProps _self;
  final $Res Function(AccessControlProps) _then;

/// Create a copy of AccessControlProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enable = null,Object? mode = null,Object? acceptList = null,Object? rejectList = null,Object? sort = null,Object? isFilterSystemApp = null,Object? isFilterNonInternetApp = null,}) {
  return _then(_self.copyWith(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as AccessControlMode,acceptList: null == acceptList ? _self.acceptList : acceptList // ignore: cast_nullable_to_non_nullable
as List<String>,rejectList: null == rejectList ? _self.rejectList : rejectList // ignore: cast_nullable_to_non_nullable
as List<String>,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as AccessSortType,isFilterSystemApp: null == isFilterSystemApp ? _self.isFilterSystemApp : isFilterSystemApp // ignore: cast_nullable_to_non_nullable
as bool,isFilterNonInternetApp: null == isFilterNonInternetApp ? _self.isFilterNonInternetApp : isFilterNonInternetApp // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AccessControlProps].
extension AccessControlPropsPatterns on AccessControlProps {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccessControlProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccessControlProps() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccessControlProps value)  $default,){
final _that = this;
switch (_that) {
case _AccessControlProps():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccessControlProps value)?  $default,){
final _that = this;
switch (_that) {
case _AccessControlProps() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enable, @JsonKey(unknownEnumValue: AccessControlMode.rejectSelected)  AccessControlMode mode,  List<String> acceptList,  List<String> rejectList, @JsonKey(unknownEnumValue: AccessSortType.none)  AccessSortType sort,  bool isFilterSystemApp,  bool isFilterNonInternetApp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccessControlProps() when $default != null:
return $default(_that.enable,_that.mode,_that.acceptList,_that.rejectList,_that.sort,_that.isFilterSystemApp,_that.isFilterNonInternetApp);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enable, @JsonKey(unknownEnumValue: AccessControlMode.rejectSelected)  AccessControlMode mode,  List<String> acceptList,  List<String> rejectList, @JsonKey(unknownEnumValue: AccessSortType.none)  AccessSortType sort,  bool isFilterSystemApp,  bool isFilterNonInternetApp)  $default,) {final _that = this;
switch (_that) {
case _AccessControlProps():
return $default(_that.enable,_that.mode,_that.acceptList,_that.rejectList,_that.sort,_that.isFilterSystemApp,_that.isFilterNonInternetApp);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enable, @JsonKey(unknownEnumValue: AccessControlMode.rejectSelected)  AccessControlMode mode,  List<String> acceptList,  List<String> rejectList, @JsonKey(unknownEnumValue: AccessSortType.none)  AccessSortType sort,  bool isFilterSystemApp,  bool isFilterNonInternetApp)?  $default,) {final _that = this;
switch (_that) {
case _AccessControlProps() when $default != null:
return $default(_that.enable,_that.mode,_that.acceptList,_that.rejectList,_that.sort,_that.isFilterSystemApp,_that.isFilterNonInternetApp);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccessControlProps implements AccessControlProps {
  const _AccessControlProps({this.enable = false, @JsonKey(unknownEnumValue: AccessControlMode.rejectSelected) this.mode = AccessControlMode.rejectSelected, final  List<String> acceptList = const [], final  List<String> rejectList = const [], @JsonKey(unknownEnumValue: AccessSortType.none) this.sort = AccessSortType.none, this.isFilterSystemApp = true, this.isFilterNonInternetApp = true}): _acceptList = acceptList,_rejectList = rejectList;
  factory _AccessControlProps.fromJson(Map<String, dynamic> json) => _$AccessControlPropsFromJson(json);

@override@JsonKey() final  bool enable;
@override@JsonKey(unknownEnumValue: AccessControlMode.rejectSelected) final  AccessControlMode mode;
 final  List<String> _acceptList;
@override@JsonKey() List<String> get acceptList {
  if (_acceptList is EqualUnmodifiableListView) return _acceptList;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_acceptList);
}

 final  List<String> _rejectList;
@override@JsonKey() List<String> get rejectList {
  if (_rejectList is EqualUnmodifiableListView) return _rejectList;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rejectList);
}

@override@JsonKey(unknownEnumValue: AccessSortType.none) final  AccessSortType sort;
@override@JsonKey() final  bool isFilterSystemApp;
@override@JsonKey() final  bool isFilterNonInternetApp;

/// Create a copy of AccessControlProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccessControlPropsCopyWith<_AccessControlProps> get copyWith => __$AccessControlPropsCopyWithImpl<_AccessControlProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccessControlPropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccessControlProps&&(identical(other.enable, enable) || other.enable == enable)&&(identical(other.mode, mode) || other.mode == mode)&&const DeepCollectionEquality().equals(other._acceptList, _acceptList)&&const DeepCollectionEquality().equals(other._rejectList, _rejectList)&&(identical(other.sort, sort) || other.sort == sort)&&(identical(other.isFilterSystemApp, isFilterSystemApp) || other.isFilterSystemApp == isFilterSystemApp)&&(identical(other.isFilterNonInternetApp, isFilterNonInternetApp) || other.isFilterNonInternetApp == isFilterNonInternetApp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enable,mode,const DeepCollectionEquality().hash(_acceptList),const DeepCollectionEquality().hash(_rejectList),sort,isFilterSystemApp,isFilterNonInternetApp);

@override
String toString() {
  return 'AccessControlProps(enable: $enable, mode: $mode, acceptList: $acceptList, rejectList: $rejectList, sort: $sort, isFilterSystemApp: $isFilterSystemApp, isFilterNonInternetApp: $isFilterNonInternetApp)';
}


}

/// @nodoc
abstract mixin class _$AccessControlPropsCopyWith<$Res> implements $AccessControlPropsCopyWith<$Res> {
  factory _$AccessControlPropsCopyWith(_AccessControlProps value, $Res Function(_AccessControlProps) _then) = __$AccessControlPropsCopyWithImpl;
@override @useResult
$Res call({
 bool enable,@JsonKey(unknownEnumValue: AccessControlMode.rejectSelected) AccessControlMode mode, List<String> acceptList, List<String> rejectList,@JsonKey(unknownEnumValue: AccessSortType.none) AccessSortType sort, bool isFilterSystemApp, bool isFilterNonInternetApp
});




}
/// @nodoc
class __$AccessControlPropsCopyWithImpl<$Res>
    implements _$AccessControlPropsCopyWith<$Res> {
  __$AccessControlPropsCopyWithImpl(this._self, this._then);

  final _AccessControlProps _self;
  final $Res Function(_AccessControlProps) _then;

/// Create a copy of AccessControlProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enable = null,Object? mode = null,Object? acceptList = null,Object? rejectList = null,Object? sort = null,Object? isFilterSystemApp = null,Object? isFilterNonInternetApp = null,}) {
  return _then(_AccessControlProps(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as AccessControlMode,acceptList: null == acceptList ? _self._acceptList : acceptList // ignore: cast_nullable_to_non_nullable
as List<String>,rejectList: null == rejectList ? _self._rejectList : rejectList // ignore: cast_nullable_to_non_nullable
as List<String>,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as AccessSortType,isFilterSystemApp: null == isFilterSystemApp ? _self.isFilterSystemApp : isFilterSystemApp // ignore: cast_nullable_to_non_nullable
as bool,isFilterNonInternetApp: null == isFilterNonInternetApp ? _self.isFilterNonInternetApp : isFilterNonInternetApp // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$WindowProps {

 double get width; double get height; double? get top; double? get left;
/// Create a copy of WindowProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WindowPropsCopyWith<WindowProps> get copyWith => _$WindowPropsCopyWithImpl<WindowProps>(this as WindowProps, _$identity);

  /// Serializes this WindowProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WindowProps&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.top, top) || other.top == top)&&(identical(other.left, left) || other.left == left));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,width,height,top,left);

@override
String toString() {
  return 'WindowProps(width: $width, height: $height, top: $top, left: $left)';
}


}

/// @nodoc
abstract mixin class $WindowPropsCopyWith<$Res>  {
  factory $WindowPropsCopyWith(WindowProps value, $Res Function(WindowProps) _then) = _$WindowPropsCopyWithImpl;
@useResult
$Res call({
 double width, double height, double? top, double? left
});




}
/// @nodoc
class _$WindowPropsCopyWithImpl<$Res>
    implements $WindowPropsCopyWith<$Res> {
  _$WindowPropsCopyWithImpl(this._self, this._then);

  final WindowProps _self;
  final $Res Function(WindowProps) _then;

/// Create a copy of WindowProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? width = null,Object? height = null,Object? top = freezed,Object? left = freezed,}) {
  return _then(_self.copyWith(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,top: freezed == top ? _self.top : top // ignore: cast_nullable_to_non_nullable
as double?,left: freezed == left ? _self.left : left // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [WindowProps].
extension WindowPropsPatterns on WindowProps {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WindowProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WindowProps() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WindowProps value)  $default,){
final _that = this;
switch (_that) {
case _WindowProps():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WindowProps value)?  $default,){
final _that = this;
switch (_that) {
case _WindowProps() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double width,  double height,  double? top,  double? left)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WindowProps() when $default != null:
return $default(_that.width,_that.height,_that.top,_that.left);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double width,  double height,  double? top,  double? left)  $default,) {final _that = this;
switch (_that) {
case _WindowProps():
return $default(_that.width,_that.height,_that.top,_that.left);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double width,  double height,  double? top,  double? left)?  $default,) {final _that = this;
switch (_that) {
case _WindowProps() when $default != null:
return $default(_that.width,_that.height,_that.top,_that.left);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WindowProps implements WindowProps {
  const _WindowProps({this.width = 0, this.height = 0, this.top, this.left});
  factory _WindowProps.fromJson(Map<String, dynamic> json) => _$WindowPropsFromJson(json);

@override@JsonKey() final  double width;
@override@JsonKey() final  double height;
@override final  double? top;
@override final  double? left;

/// Create a copy of WindowProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WindowPropsCopyWith<_WindowProps> get copyWith => __$WindowPropsCopyWithImpl<_WindowProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WindowPropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WindowProps&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.top, top) || other.top == top)&&(identical(other.left, left) || other.left == left));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,width,height,top,left);

@override
String toString() {
  return 'WindowProps(width: $width, height: $height, top: $top, left: $left)';
}


}

/// @nodoc
abstract mixin class _$WindowPropsCopyWith<$Res> implements $WindowPropsCopyWith<$Res> {
  factory _$WindowPropsCopyWith(_WindowProps value, $Res Function(_WindowProps) _then) = __$WindowPropsCopyWithImpl;
@override @useResult
$Res call({
 double width, double height, double? top, double? left
});




}
/// @nodoc
class __$WindowPropsCopyWithImpl<$Res>
    implements _$WindowPropsCopyWith<$Res> {
  __$WindowPropsCopyWithImpl(this._self, this._then);

  final _WindowProps _self;
  final $Res Function(_WindowProps) _then;

/// Create a copy of WindowProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? width = null,Object? height = null,Object? top = freezed,Object? left = freezed,}) {
  return _then(_WindowProps(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,top: freezed == top ? _self.top : top // ignore: cast_nullable_to_non_nullable
as double?,left: freezed == left ? _self.left : left // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$VpnProps {

 bool get enable; bool get systemProxy; bool get ipv6; bool get allowBypass; bool get dnsHijacking; bool get suspendSupport; bool get networkSpeedNotification; bool get includeAllNetworks; bool get excludeLocalNetworks; bool get excludeAPNs; bool get excludeCellularServices; bool get enforceRoutes; bool get excludeDeviceCommunication; AccessControlProps get accessControlProps;
/// Create a copy of VpnProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VpnPropsCopyWith<VpnProps> get copyWith => _$VpnPropsCopyWithImpl<VpnProps>(this as VpnProps, _$identity);

  /// Serializes this VpnProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VpnProps&&(identical(other.enable, enable) || other.enable == enable)&&(identical(other.systemProxy, systemProxy) || other.systemProxy == systemProxy)&&(identical(other.ipv6, ipv6) || other.ipv6 == ipv6)&&(identical(other.allowBypass, allowBypass) || other.allowBypass == allowBypass)&&(identical(other.dnsHijacking, dnsHijacking) || other.dnsHijacking == dnsHijacking)&&(identical(other.suspendSupport, suspendSupport) || other.suspendSupport == suspendSupport)&&(identical(other.networkSpeedNotification, networkSpeedNotification) || other.networkSpeedNotification == networkSpeedNotification)&&(identical(other.includeAllNetworks, includeAllNetworks) || other.includeAllNetworks == includeAllNetworks)&&(identical(other.excludeLocalNetworks, excludeLocalNetworks) || other.excludeLocalNetworks == excludeLocalNetworks)&&(identical(other.excludeAPNs, excludeAPNs) || other.excludeAPNs == excludeAPNs)&&(identical(other.excludeCellularServices, excludeCellularServices) || other.excludeCellularServices == excludeCellularServices)&&(identical(other.enforceRoutes, enforceRoutes) || other.enforceRoutes == enforceRoutes)&&(identical(other.excludeDeviceCommunication, excludeDeviceCommunication) || other.excludeDeviceCommunication == excludeDeviceCommunication)&&(identical(other.accessControlProps, accessControlProps) || other.accessControlProps == accessControlProps));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enable,systemProxy,ipv6,allowBypass,dnsHijacking,suspendSupport,networkSpeedNotification,includeAllNetworks,excludeLocalNetworks,excludeAPNs,excludeCellularServices,enforceRoutes,excludeDeviceCommunication,accessControlProps);

@override
String toString() {
  return 'VpnProps(enable: $enable, systemProxy: $systemProxy, ipv6: $ipv6, allowBypass: $allowBypass, dnsHijacking: $dnsHijacking, suspendSupport: $suspendSupport, networkSpeedNotification: $networkSpeedNotification, includeAllNetworks: $includeAllNetworks, excludeLocalNetworks: $excludeLocalNetworks, excludeAPNs: $excludeAPNs, excludeCellularServices: $excludeCellularServices, enforceRoutes: $enforceRoutes, excludeDeviceCommunication: $excludeDeviceCommunication, accessControlProps: $accessControlProps)';
}


}

/// @nodoc
abstract mixin class $VpnPropsCopyWith<$Res>  {
  factory $VpnPropsCopyWith(VpnProps value, $Res Function(VpnProps) _then) = _$VpnPropsCopyWithImpl;
@useResult
$Res call({
 bool enable, bool systemProxy, bool ipv6, bool allowBypass, bool dnsHijacking, bool suspendSupport, bool networkSpeedNotification, bool includeAllNetworks, bool excludeLocalNetworks, bool excludeAPNs, bool excludeCellularServices, bool enforceRoutes, bool excludeDeviceCommunication, AccessControlProps accessControlProps
});


$AccessControlPropsCopyWith<$Res> get accessControlProps;

}
/// @nodoc
class _$VpnPropsCopyWithImpl<$Res>
    implements $VpnPropsCopyWith<$Res> {
  _$VpnPropsCopyWithImpl(this._self, this._then);

  final VpnProps _self;
  final $Res Function(VpnProps) _then;

/// Create a copy of VpnProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enable = null,Object? systemProxy = null,Object? ipv6 = null,Object? allowBypass = null,Object? dnsHijacking = null,Object? suspendSupport = null,Object? networkSpeedNotification = null,Object? includeAllNetworks = null,Object? excludeLocalNetworks = null,Object? excludeAPNs = null,Object? excludeCellularServices = null,Object? enforceRoutes = null,Object? excludeDeviceCommunication = null,Object? accessControlProps = null,}) {
  return _then(_self.copyWith(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,systemProxy: null == systemProxy ? _self.systemProxy : systemProxy // ignore: cast_nullable_to_non_nullable
as bool,ipv6: null == ipv6 ? _self.ipv6 : ipv6 // ignore: cast_nullable_to_non_nullable
as bool,allowBypass: null == allowBypass ? _self.allowBypass : allowBypass // ignore: cast_nullable_to_non_nullable
as bool,dnsHijacking: null == dnsHijacking ? _self.dnsHijacking : dnsHijacking // ignore: cast_nullable_to_non_nullable
as bool,suspendSupport: null == suspendSupport ? _self.suspendSupport : suspendSupport // ignore: cast_nullable_to_non_nullable
as bool,networkSpeedNotification: null == networkSpeedNotification ? _self.networkSpeedNotification : networkSpeedNotification // ignore: cast_nullable_to_non_nullable
as bool,includeAllNetworks: null == includeAllNetworks ? _self.includeAllNetworks : includeAllNetworks // ignore: cast_nullable_to_non_nullable
as bool,excludeLocalNetworks: null == excludeLocalNetworks ? _self.excludeLocalNetworks : excludeLocalNetworks // ignore: cast_nullable_to_non_nullable
as bool,excludeAPNs: null == excludeAPNs ? _self.excludeAPNs : excludeAPNs // ignore: cast_nullable_to_non_nullable
as bool,excludeCellularServices: null == excludeCellularServices ? _self.excludeCellularServices : excludeCellularServices // ignore: cast_nullable_to_non_nullable
as bool,enforceRoutes: null == enforceRoutes ? _self.enforceRoutes : enforceRoutes // ignore: cast_nullable_to_non_nullable
as bool,excludeDeviceCommunication: null == excludeDeviceCommunication ? _self.excludeDeviceCommunication : excludeDeviceCommunication // ignore: cast_nullable_to_non_nullable
as bool,accessControlProps: null == accessControlProps ? _self.accessControlProps : accessControlProps // ignore: cast_nullable_to_non_nullable
as AccessControlProps,
  ));
}
/// Create a copy of VpnProps
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AccessControlPropsCopyWith<$Res> get accessControlProps {
  
  return $AccessControlPropsCopyWith<$Res>(_self.accessControlProps, (value) {
    return _then(_self.copyWith(accessControlProps: value));
  });
}
}


/// Adds pattern-matching-related methods to [VpnProps].
extension VpnPropsPatterns on VpnProps {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VpnProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VpnProps() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VpnProps value)  $default,){
final _that = this;
switch (_that) {
case _VpnProps():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VpnProps value)?  $default,){
final _that = this;
switch (_that) {
case _VpnProps() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enable,  bool systemProxy,  bool ipv6,  bool allowBypass,  bool dnsHijacking,  bool suspendSupport,  bool networkSpeedNotification,  bool includeAllNetworks,  bool excludeLocalNetworks,  bool excludeAPNs,  bool excludeCellularServices,  bool enforceRoutes,  bool excludeDeviceCommunication,  AccessControlProps accessControlProps)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VpnProps() when $default != null:
return $default(_that.enable,_that.systemProxy,_that.ipv6,_that.allowBypass,_that.dnsHijacking,_that.suspendSupport,_that.networkSpeedNotification,_that.includeAllNetworks,_that.excludeLocalNetworks,_that.excludeAPNs,_that.excludeCellularServices,_that.enforceRoutes,_that.excludeDeviceCommunication,_that.accessControlProps);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enable,  bool systemProxy,  bool ipv6,  bool allowBypass,  bool dnsHijacking,  bool suspendSupport,  bool networkSpeedNotification,  bool includeAllNetworks,  bool excludeLocalNetworks,  bool excludeAPNs,  bool excludeCellularServices,  bool enforceRoutes,  bool excludeDeviceCommunication,  AccessControlProps accessControlProps)  $default,) {final _that = this;
switch (_that) {
case _VpnProps():
return $default(_that.enable,_that.systemProxy,_that.ipv6,_that.allowBypass,_that.dnsHijacking,_that.suspendSupport,_that.networkSpeedNotification,_that.includeAllNetworks,_that.excludeLocalNetworks,_that.excludeAPNs,_that.excludeCellularServices,_that.enforceRoutes,_that.excludeDeviceCommunication,_that.accessControlProps);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enable,  bool systemProxy,  bool ipv6,  bool allowBypass,  bool dnsHijacking,  bool suspendSupport,  bool networkSpeedNotification,  bool includeAllNetworks,  bool excludeLocalNetworks,  bool excludeAPNs,  bool excludeCellularServices,  bool enforceRoutes,  bool excludeDeviceCommunication,  AccessControlProps accessControlProps)?  $default,) {final _that = this;
switch (_that) {
case _VpnProps() when $default != null:
return $default(_that.enable,_that.systemProxy,_that.ipv6,_that.allowBypass,_that.dnsHijacking,_that.suspendSupport,_that.networkSpeedNotification,_that.includeAllNetworks,_that.excludeLocalNetworks,_that.excludeAPNs,_that.excludeCellularServices,_that.enforceRoutes,_that.excludeDeviceCommunication,_that.accessControlProps);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VpnProps implements VpnProps {
  const _VpnProps({this.enable = true, this.systemProxy = true, this.ipv6 = false, this.allowBypass = true, this.dnsHijacking = false, this.suspendSupport = true, this.networkSpeedNotification = false, this.includeAllNetworks = false, this.excludeLocalNetworks = true, this.excludeAPNs = true, this.excludeCellularServices = true, this.enforceRoutes = false, this.excludeDeviceCommunication = true, this.accessControlProps = defaultAccessControlProps});
  factory _VpnProps.fromJson(Map<String, dynamic> json) => _$VpnPropsFromJson(json);

@override@JsonKey() final  bool enable;
@override@JsonKey() final  bool systemProxy;
@override@JsonKey() final  bool ipv6;
@override@JsonKey() final  bool allowBypass;
@override@JsonKey() final  bool dnsHijacking;
@override@JsonKey() final  bool suspendSupport;
@override@JsonKey() final  bool networkSpeedNotification;
@override@JsonKey() final  bool includeAllNetworks;
@override@JsonKey() final  bool excludeLocalNetworks;
@override@JsonKey() final  bool excludeAPNs;
@override@JsonKey() final  bool excludeCellularServices;
@override@JsonKey() final  bool enforceRoutes;
@override@JsonKey() final  bool excludeDeviceCommunication;
@override@JsonKey() final  AccessControlProps accessControlProps;

/// Create a copy of VpnProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VpnPropsCopyWith<_VpnProps> get copyWith => __$VpnPropsCopyWithImpl<_VpnProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VpnPropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VpnProps&&(identical(other.enable, enable) || other.enable == enable)&&(identical(other.systemProxy, systemProxy) || other.systemProxy == systemProxy)&&(identical(other.ipv6, ipv6) || other.ipv6 == ipv6)&&(identical(other.allowBypass, allowBypass) || other.allowBypass == allowBypass)&&(identical(other.dnsHijacking, dnsHijacking) || other.dnsHijacking == dnsHijacking)&&(identical(other.suspendSupport, suspendSupport) || other.suspendSupport == suspendSupport)&&(identical(other.networkSpeedNotification, networkSpeedNotification) || other.networkSpeedNotification == networkSpeedNotification)&&(identical(other.includeAllNetworks, includeAllNetworks) || other.includeAllNetworks == includeAllNetworks)&&(identical(other.excludeLocalNetworks, excludeLocalNetworks) || other.excludeLocalNetworks == excludeLocalNetworks)&&(identical(other.excludeAPNs, excludeAPNs) || other.excludeAPNs == excludeAPNs)&&(identical(other.excludeCellularServices, excludeCellularServices) || other.excludeCellularServices == excludeCellularServices)&&(identical(other.enforceRoutes, enforceRoutes) || other.enforceRoutes == enforceRoutes)&&(identical(other.excludeDeviceCommunication, excludeDeviceCommunication) || other.excludeDeviceCommunication == excludeDeviceCommunication)&&(identical(other.accessControlProps, accessControlProps) || other.accessControlProps == accessControlProps));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enable,systemProxy,ipv6,allowBypass,dnsHijacking,suspendSupport,networkSpeedNotification,includeAllNetworks,excludeLocalNetworks,excludeAPNs,excludeCellularServices,enforceRoutes,excludeDeviceCommunication,accessControlProps);

@override
String toString() {
  return 'VpnProps(enable: $enable, systemProxy: $systemProxy, ipv6: $ipv6, allowBypass: $allowBypass, dnsHijacking: $dnsHijacking, suspendSupport: $suspendSupport, networkSpeedNotification: $networkSpeedNotification, includeAllNetworks: $includeAllNetworks, excludeLocalNetworks: $excludeLocalNetworks, excludeAPNs: $excludeAPNs, excludeCellularServices: $excludeCellularServices, enforceRoutes: $enforceRoutes, excludeDeviceCommunication: $excludeDeviceCommunication, accessControlProps: $accessControlProps)';
}


}

/// @nodoc
abstract mixin class _$VpnPropsCopyWith<$Res> implements $VpnPropsCopyWith<$Res> {
  factory _$VpnPropsCopyWith(_VpnProps value, $Res Function(_VpnProps) _then) = __$VpnPropsCopyWithImpl;
@override @useResult
$Res call({
 bool enable, bool systemProxy, bool ipv6, bool allowBypass, bool dnsHijacking, bool suspendSupport, bool networkSpeedNotification, bool includeAllNetworks, bool excludeLocalNetworks, bool excludeAPNs, bool excludeCellularServices, bool enforceRoutes, bool excludeDeviceCommunication, AccessControlProps accessControlProps
});


@override $AccessControlPropsCopyWith<$Res> get accessControlProps;

}
/// @nodoc
class __$VpnPropsCopyWithImpl<$Res>
    implements _$VpnPropsCopyWith<$Res> {
  __$VpnPropsCopyWithImpl(this._self, this._then);

  final _VpnProps _self;
  final $Res Function(_VpnProps) _then;

/// Create a copy of VpnProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enable = null,Object? systemProxy = null,Object? ipv6 = null,Object? allowBypass = null,Object? dnsHijacking = null,Object? suspendSupport = null,Object? networkSpeedNotification = null,Object? includeAllNetworks = null,Object? excludeLocalNetworks = null,Object? excludeAPNs = null,Object? excludeCellularServices = null,Object? enforceRoutes = null,Object? excludeDeviceCommunication = null,Object? accessControlProps = null,}) {
  return _then(_VpnProps(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,systemProxy: null == systemProxy ? _self.systemProxy : systemProxy // ignore: cast_nullable_to_non_nullable
as bool,ipv6: null == ipv6 ? _self.ipv6 : ipv6 // ignore: cast_nullable_to_non_nullable
as bool,allowBypass: null == allowBypass ? _self.allowBypass : allowBypass // ignore: cast_nullable_to_non_nullable
as bool,dnsHijacking: null == dnsHijacking ? _self.dnsHijacking : dnsHijacking // ignore: cast_nullable_to_non_nullable
as bool,suspendSupport: null == suspendSupport ? _self.suspendSupport : suspendSupport // ignore: cast_nullable_to_non_nullable
as bool,networkSpeedNotification: null == networkSpeedNotification ? _self.networkSpeedNotification : networkSpeedNotification // ignore: cast_nullable_to_non_nullable
as bool,includeAllNetworks: null == includeAllNetworks ? _self.includeAllNetworks : includeAllNetworks // ignore: cast_nullable_to_non_nullable
as bool,excludeLocalNetworks: null == excludeLocalNetworks ? _self.excludeLocalNetworks : excludeLocalNetworks // ignore: cast_nullable_to_non_nullable
as bool,excludeAPNs: null == excludeAPNs ? _self.excludeAPNs : excludeAPNs // ignore: cast_nullable_to_non_nullable
as bool,excludeCellularServices: null == excludeCellularServices ? _self.excludeCellularServices : excludeCellularServices // ignore: cast_nullable_to_non_nullable
as bool,enforceRoutes: null == enforceRoutes ? _self.enforceRoutes : enforceRoutes // ignore: cast_nullable_to_non_nullable
as bool,excludeDeviceCommunication: null == excludeDeviceCommunication ? _self.excludeDeviceCommunication : excludeDeviceCommunication // ignore: cast_nullable_to_non_nullable
as bool,accessControlProps: null == accessControlProps ? _self.accessControlProps : accessControlProps // ignore: cast_nullable_to_non_nullable
as AccessControlProps,
  ));
}

/// Create a copy of VpnProps
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AccessControlPropsCopyWith<$Res> get accessControlProps {
  
  return $AccessControlPropsCopyWith<$Res>(_self.accessControlProps, (value) {
    return _then(_self.copyWith(accessControlProps: value));
  });
}
}


/// @nodoc
mixin _$NetworkProps {

 bool get systemProxy; List<String> get bypassDomain;@JsonKey(unknownEnumValue: RouteMode.config) RouteMode get routeMode; bool get autoSetSystemDns; bool get appendSystemDns;
/// Create a copy of NetworkProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NetworkPropsCopyWith<NetworkProps> get copyWith => _$NetworkPropsCopyWithImpl<NetworkProps>(this as NetworkProps, _$identity);

  /// Serializes this NetworkProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NetworkProps&&(identical(other.systemProxy, systemProxy) || other.systemProxy == systemProxy)&&const DeepCollectionEquality().equals(other.bypassDomain, bypassDomain)&&(identical(other.routeMode, routeMode) || other.routeMode == routeMode)&&(identical(other.autoSetSystemDns, autoSetSystemDns) || other.autoSetSystemDns == autoSetSystemDns)&&(identical(other.appendSystemDns, appendSystemDns) || other.appendSystemDns == appendSystemDns));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,systemProxy,const DeepCollectionEquality().hash(bypassDomain),routeMode,autoSetSystemDns,appendSystemDns);

@override
String toString() {
  return 'NetworkProps(systemProxy: $systemProxy, bypassDomain: $bypassDomain, routeMode: $routeMode, autoSetSystemDns: $autoSetSystemDns, appendSystemDns: $appendSystemDns)';
}


}

/// @nodoc
abstract mixin class $NetworkPropsCopyWith<$Res>  {
  factory $NetworkPropsCopyWith(NetworkProps value, $Res Function(NetworkProps) _then) = _$NetworkPropsCopyWithImpl;
@useResult
$Res call({
 bool systemProxy, List<String> bypassDomain,@JsonKey(unknownEnumValue: RouteMode.config) RouteMode routeMode, bool autoSetSystemDns, bool appendSystemDns
});




}
/// @nodoc
class _$NetworkPropsCopyWithImpl<$Res>
    implements $NetworkPropsCopyWith<$Res> {
  _$NetworkPropsCopyWithImpl(this._self, this._then);

  final NetworkProps _self;
  final $Res Function(NetworkProps) _then;

/// Create a copy of NetworkProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? systemProxy = null,Object? bypassDomain = null,Object? routeMode = null,Object? autoSetSystemDns = null,Object? appendSystemDns = null,}) {
  return _then(_self.copyWith(
systemProxy: null == systemProxy ? _self.systemProxy : systemProxy // ignore: cast_nullable_to_non_nullable
as bool,bypassDomain: null == bypassDomain ? _self.bypassDomain : bypassDomain // ignore: cast_nullable_to_non_nullable
as List<String>,routeMode: null == routeMode ? _self.routeMode : routeMode // ignore: cast_nullable_to_non_nullable
as RouteMode,autoSetSystemDns: null == autoSetSystemDns ? _self.autoSetSystemDns : autoSetSystemDns // ignore: cast_nullable_to_non_nullable
as bool,appendSystemDns: null == appendSystemDns ? _self.appendSystemDns : appendSystemDns // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [NetworkProps].
extension NetworkPropsPatterns on NetworkProps {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NetworkProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NetworkProps() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NetworkProps value)  $default,){
final _that = this;
switch (_that) {
case _NetworkProps():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NetworkProps value)?  $default,){
final _that = this;
switch (_that) {
case _NetworkProps() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool systemProxy,  List<String> bypassDomain, @JsonKey(unknownEnumValue: RouteMode.config)  RouteMode routeMode,  bool autoSetSystemDns,  bool appendSystemDns)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NetworkProps() when $default != null:
return $default(_that.systemProxy,_that.bypassDomain,_that.routeMode,_that.autoSetSystemDns,_that.appendSystemDns);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool systemProxy,  List<String> bypassDomain, @JsonKey(unknownEnumValue: RouteMode.config)  RouteMode routeMode,  bool autoSetSystemDns,  bool appendSystemDns)  $default,) {final _that = this;
switch (_that) {
case _NetworkProps():
return $default(_that.systemProxy,_that.bypassDomain,_that.routeMode,_that.autoSetSystemDns,_that.appendSystemDns);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool systemProxy,  List<String> bypassDomain, @JsonKey(unknownEnumValue: RouteMode.config)  RouteMode routeMode,  bool autoSetSystemDns,  bool appendSystemDns)?  $default,) {final _that = this;
switch (_that) {
case _NetworkProps() when $default != null:
return $default(_that.systemProxy,_that.bypassDomain,_that.routeMode,_that.autoSetSystemDns,_that.appendSystemDns);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NetworkProps implements NetworkProps {
  const _NetworkProps({this.systemProxy = true, final  List<String> bypassDomain = defaultBypassDomain, @JsonKey(unknownEnumValue: RouteMode.config) this.routeMode = RouteMode.config, this.autoSetSystemDns = true, this.appendSystemDns = false}): _bypassDomain = bypassDomain;
  factory _NetworkProps.fromJson(Map<String, dynamic> json) => _$NetworkPropsFromJson(json);

@override@JsonKey() final  bool systemProxy;
 final  List<String> _bypassDomain;
@override@JsonKey() List<String> get bypassDomain {
  if (_bypassDomain is EqualUnmodifiableListView) return _bypassDomain;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bypassDomain);
}

@override@JsonKey(unknownEnumValue: RouteMode.config) final  RouteMode routeMode;
@override@JsonKey() final  bool autoSetSystemDns;
@override@JsonKey() final  bool appendSystemDns;

/// Create a copy of NetworkProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NetworkPropsCopyWith<_NetworkProps> get copyWith => __$NetworkPropsCopyWithImpl<_NetworkProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NetworkPropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NetworkProps&&(identical(other.systemProxy, systemProxy) || other.systemProxy == systemProxy)&&const DeepCollectionEquality().equals(other._bypassDomain, _bypassDomain)&&(identical(other.routeMode, routeMode) || other.routeMode == routeMode)&&(identical(other.autoSetSystemDns, autoSetSystemDns) || other.autoSetSystemDns == autoSetSystemDns)&&(identical(other.appendSystemDns, appendSystemDns) || other.appendSystemDns == appendSystemDns));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,systemProxy,const DeepCollectionEquality().hash(_bypassDomain),routeMode,autoSetSystemDns,appendSystemDns);

@override
String toString() {
  return 'NetworkProps(systemProxy: $systemProxy, bypassDomain: $bypassDomain, routeMode: $routeMode, autoSetSystemDns: $autoSetSystemDns, appendSystemDns: $appendSystemDns)';
}


}

/// @nodoc
abstract mixin class _$NetworkPropsCopyWith<$Res> implements $NetworkPropsCopyWith<$Res> {
  factory _$NetworkPropsCopyWith(_NetworkProps value, $Res Function(_NetworkProps) _then) = __$NetworkPropsCopyWithImpl;
@override @useResult
$Res call({
 bool systemProxy, List<String> bypassDomain,@JsonKey(unknownEnumValue: RouteMode.config) RouteMode routeMode, bool autoSetSystemDns, bool appendSystemDns
});




}
/// @nodoc
class __$NetworkPropsCopyWithImpl<$Res>
    implements _$NetworkPropsCopyWith<$Res> {
  __$NetworkPropsCopyWithImpl(this._self, this._then);

  final _NetworkProps _self;
  final $Res Function(_NetworkProps) _then;

/// Create a copy of NetworkProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? systemProxy = null,Object? bypassDomain = null,Object? routeMode = null,Object? autoSetSystemDns = null,Object? appendSystemDns = null,}) {
  return _then(_NetworkProps(
systemProxy: null == systemProxy ? _self.systemProxy : systemProxy // ignore: cast_nullable_to_non_nullable
as bool,bypassDomain: null == bypassDomain ? _self._bypassDomain : bypassDomain // ignore: cast_nullable_to_non_nullable
as List<String>,routeMode: null == routeMode ? _self.routeMode : routeMode // ignore: cast_nullable_to_non_nullable
as RouteMode,autoSetSystemDns: null == autoSetSystemDns ? _self.autoSetSystemDns : autoSetSystemDns // ignore: cast_nullable_to_non_nullable
as bool,appendSystemDns: null == appendSystemDns ? _self.appendSystemDns : appendSystemDns // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ProxiesStyleProps {

@JsonKey(unknownEnumValue: ProxiesType.tab) ProxiesType get type;@JsonKey(unknownEnumValue: ProxiesSortType.none) ProxiesSortType get sortType;@JsonKey(unknownEnumValue: ProxiesLayout.standard) ProxiesLayout get layout;@JsonKey(unknownEnumValue: ProxiesListHeaderStyle.loose) ProxiesListHeaderStyle get listHeaderStyle;@JsonKey(unknownEnumValue: ProxiesIconStyle.standard) ProxiesIconStyle get iconStyle;@JsonKey(unknownEnumValue: ProxiesIconSource.standard) ProxiesIconSource get iconSource;@JsonKey(unknownEnumValue: ProxyCardType.standard) ProxyCardType get cardType; bool get hideUnavailable;
/// Create a copy of ProxiesStyleProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProxiesStylePropsCopyWith<ProxiesStyleProps> get copyWith => _$ProxiesStylePropsCopyWithImpl<ProxiesStyleProps>(this as ProxiesStyleProps, _$identity);

  /// Serializes this ProxiesStyleProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProxiesStyleProps&&(identical(other.type, type) || other.type == type)&&(identical(other.sortType, sortType) || other.sortType == sortType)&&(identical(other.layout, layout) || other.layout == layout)&&(identical(other.listHeaderStyle, listHeaderStyle) || other.listHeaderStyle == listHeaderStyle)&&(identical(other.iconStyle, iconStyle) || other.iconStyle == iconStyle)&&(identical(other.iconSource, iconSource) || other.iconSource == iconSource)&&(identical(other.cardType, cardType) || other.cardType == cardType)&&(identical(other.hideUnavailable, hideUnavailable) || other.hideUnavailable == hideUnavailable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,sortType,layout,listHeaderStyle,iconStyle,iconSource,cardType,hideUnavailable);

@override
String toString() {
  return 'ProxiesStyleProps(type: $type, sortType: $sortType, layout: $layout, listHeaderStyle: $listHeaderStyle, iconStyle: $iconStyle, iconSource: $iconSource, cardType: $cardType, hideUnavailable: $hideUnavailable)';
}


}

/// @nodoc
abstract mixin class $ProxiesStylePropsCopyWith<$Res>  {
  factory $ProxiesStylePropsCopyWith(ProxiesStyleProps value, $Res Function(ProxiesStyleProps) _then) = _$ProxiesStylePropsCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: ProxiesType.tab) ProxiesType type,@JsonKey(unknownEnumValue: ProxiesSortType.none) ProxiesSortType sortType,@JsonKey(unknownEnumValue: ProxiesLayout.standard) ProxiesLayout layout,@JsonKey(unknownEnumValue: ProxiesListHeaderStyle.loose) ProxiesListHeaderStyle listHeaderStyle,@JsonKey(unknownEnumValue: ProxiesIconStyle.standard) ProxiesIconStyle iconStyle,@JsonKey(unknownEnumValue: ProxiesIconSource.standard) ProxiesIconSource iconSource,@JsonKey(unknownEnumValue: ProxyCardType.standard) ProxyCardType cardType, bool hideUnavailable
});




}
/// @nodoc
class _$ProxiesStylePropsCopyWithImpl<$Res>
    implements $ProxiesStylePropsCopyWith<$Res> {
  _$ProxiesStylePropsCopyWithImpl(this._self, this._then);

  final ProxiesStyleProps _self;
  final $Res Function(ProxiesStyleProps) _then;

/// Create a copy of ProxiesStyleProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? sortType = null,Object? layout = null,Object? listHeaderStyle = null,Object? iconStyle = null,Object? iconSource = null,Object? cardType = null,Object? hideUnavailable = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ProxiesType,sortType: null == sortType ? _self.sortType : sortType // ignore: cast_nullable_to_non_nullable
as ProxiesSortType,layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as ProxiesLayout,listHeaderStyle: null == listHeaderStyle ? _self.listHeaderStyle : listHeaderStyle // ignore: cast_nullable_to_non_nullable
as ProxiesListHeaderStyle,iconStyle: null == iconStyle ? _self.iconStyle : iconStyle // ignore: cast_nullable_to_non_nullable
as ProxiesIconStyle,iconSource: null == iconSource ? _self.iconSource : iconSource // ignore: cast_nullable_to_non_nullable
as ProxiesIconSource,cardType: null == cardType ? _self.cardType : cardType // ignore: cast_nullable_to_non_nullable
as ProxyCardType,hideUnavailable: null == hideUnavailable ? _self.hideUnavailable : hideUnavailable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ProxiesStyleProps].
extension ProxiesStylePropsPatterns on ProxiesStyleProps {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProxiesStyleProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProxiesStyleProps() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProxiesStyleProps value)  $default,){
final _that = this;
switch (_that) {
case _ProxiesStyleProps():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProxiesStyleProps value)?  $default,){
final _that = this;
switch (_that) {
case _ProxiesStyleProps() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: ProxiesType.tab)  ProxiesType type, @JsonKey(unknownEnumValue: ProxiesSortType.none)  ProxiesSortType sortType, @JsonKey(unknownEnumValue: ProxiesLayout.standard)  ProxiesLayout layout, @JsonKey(unknownEnumValue: ProxiesListHeaderStyle.loose)  ProxiesListHeaderStyle listHeaderStyle, @JsonKey(unknownEnumValue: ProxiesIconStyle.standard)  ProxiesIconStyle iconStyle, @JsonKey(unknownEnumValue: ProxiesIconSource.standard)  ProxiesIconSource iconSource, @JsonKey(unknownEnumValue: ProxyCardType.standard)  ProxyCardType cardType,  bool hideUnavailable)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProxiesStyleProps() when $default != null:
return $default(_that.type,_that.sortType,_that.layout,_that.listHeaderStyle,_that.iconStyle,_that.iconSource,_that.cardType,_that.hideUnavailable);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: ProxiesType.tab)  ProxiesType type, @JsonKey(unknownEnumValue: ProxiesSortType.none)  ProxiesSortType sortType, @JsonKey(unknownEnumValue: ProxiesLayout.standard)  ProxiesLayout layout, @JsonKey(unknownEnumValue: ProxiesListHeaderStyle.loose)  ProxiesListHeaderStyle listHeaderStyle, @JsonKey(unknownEnumValue: ProxiesIconStyle.standard)  ProxiesIconStyle iconStyle, @JsonKey(unknownEnumValue: ProxiesIconSource.standard)  ProxiesIconSource iconSource, @JsonKey(unknownEnumValue: ProxyCardType.standard)  ProxyCardType cardType,  bool hideUnavailable)  $default,) {final _that = this;
switch (_that) {
case _ProxiesStyleProps():
return $default(_that.type,_that.sortType,_that.layout,_that.listHeaderStyle,_that.iconStyle,_that.iconSource,_that.cardType,_that.hideUnavailable);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(unknownEnumValue: ProxiesType.tab)  ProxiesType type, @JsonKey(unknownEnumValue: ProxiesSortType.none)  ProxiesSortType sortType, @JsonKey(unknownEnumValue: ProxiesLayout.standard)  ProxiesLayout layout, @JsonKey(unknownEnumValue: ProxiesListHeaderStyle.loose)  ProxiesListHeaderStyle listHeaderStyle, @JsonKey(unknownEnumValue: ProxiesIconStyle.standard)  ProxiesIconStyle iconStyle, @JsonKey(unknownEnumValue: ProxiesIconSource.standard)  ProxiesIconSource iconSource, @JsonKey(unknownEnumValue: ProxyCardType.standard)  ProxyCardType cardType,  bool hideUnavailable)?  $default,) {final _that = this;
switch (_that) {
case _ProxiesStyleProps() when $default != null:
return $default(_that.type,_that.sortType,_that.layout,_that.listHeaderStyle,_that.iconStyle,_that.iconSource,_that.cardType,_that.hideUnavailable);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProxiesStyleProps implements ProxiesStyleProps {
  const _ProxiesStyleProps({@JsonKey(unknownEnumValue: ProxiesType.tab) this.type = ProxiesType.tab, @JsonKey(unknownEnumValue: ProxiesSortType.none) this.sortType = ProxiesSortType.none, @JsonKey(unknownEnumValue: ProxiesLayout.standard) this.layout = ProxiesLayout.standard, @JsonKey(unknownEnumValue: ProxiesListHeaderStyle.loose) this.listHeaderStyle = ProxiesListHeaderStyle.loose, @JsonKey(unknownEnumValue: ProxiesIconStyle.standard) this.iconStyle = ProxiesIconStyle.standard, @JsonKey(unknownEnumValue: ProxiesIconSource.standard) this.iconSource = ProxiesIconSource.standard, @JsonKey(unknownEnumValue: ProxyCardType.standard) this.cardType = ProxyCardType.standard, this.hideUnavailable = false});
  factory _ProxiesStyleProps.fromJson(Map<String, dynamic> json) => _$ProxiesStylePropsFromJson(json);

@override@JsonKey(unknownEnumValue: ProxiesType.tab) final  ProxiesType type;
@override@JsonKey(unknownEnumValue: ProxiesSortType.none) final  ProxiesSortType sortType;
@override@JsonKey(unknownEnumValue: ProxiesLayout.standard) final  ProxiesLayout layout;
@override@JsonKey(unknownEnumValue: ProxiesListHeaderStyle.loose) final  ProxiesListHeaderStyle listHeaderStyle;
@override@JsonKey(unknownEnumValue: ProxiesIconStyle.standard) final  ProxiesIconStyle iconStyle;
@override@JsonKey(unknownEnumValue: ProxiesIconSource.standard) final  ProxiesIconSource iconSource;
@override@JsonKey(unknownEnumValue: ProxyCardType.standard) final  ProxyCardType cardType;
@override@JsonKey() final  bool hideUnavailable;

/// Create a copy of ProxiesStyleProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProxiesStylePropsCopyWith<_ProxiesStyleProps> get copyWith => __$ProxiesStylePropsCopyWithImpl<_ProxiesStyleProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProxiesStylePropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProxiesStyleProps&&(identical(other.type, type) || other.type == type)&&(identical(other.sortType, sortType) || other.sortType == sortType)&&(identical(other.layout, layout) || other.layout == layout)&&(identical(other.listHeaderStyle, listHeaderStyle) || other.listHeaderStyle == listHeaderStyle)&&(identical(other.iconStyle, iconStyle) || other.iconStyle == iconStyle)&&(identical(other.iconSource, iconSource) || other.iconSource == iconSource)&&(identical(other.cardType, cardType) || other.cardType == cardType)&&(identical(other.hideUnavailable, hideUnavailable) || other.hideUnavailable == hideUnavailable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,sortType,layout,listHeaderStyle,iconStyle,iconSource,cardType,hideUnavailable);

@override
String toString() {
  return 'ProxiesStyleProps(type: $type, sortType: $sortType, layout: $layout, listHeaderStyle: $listHeaderStyle, iconStyle: $iconStyle, iconSource: $iconSource, cardType: $cardType, hideUnavailable: $hideUnavailable)';
}


}

/// @nodoc
abstract mixin class _$ProxiesStylePropsCopyWith<$Res> implements $ProxiesStylePropsCopyWith<$Res> {
  factory _$ProxiesStylePropsCopyWith(_ProxiesStyleProps value, $Res Function(_ProxiesStyleProps) _then) = __$ProxiesStylePropsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: ProxiesType.tab) ProxiesType type,@JsonKey(unknownEnumValue: ProxiesSortType.none) ProxiesSortType sortType,@JsonKey(unknownEnumValue: ProxiesLayout.standard) ProxiesLayout layout,@JsonKey(unknownEnumValue: ProxiesListHeaderStyle.loose) ProxiesListHeaderStyle listHeaderStyle,@JsonKey(unknownEnumValue: ProxiesIconStyle.standard) ProxiesIconStyle iconStyle,@JsonKey(unknownEnumValue: ProxiesIconSource.standard) ProxiesIconSource iconSource,@JsonKey(unknownEnumValue: ProxyCardType.standard) ProxyCardType cardType, bool hideUnavailable
});




}
/// @nodoc
class __$ProxiesStylePropsCopyWithImpl<$Res>
    implements _$ProxiesStylePropsCopyWith<$Res> {
  __$ProxiesStylePropsCopyWithImpl(this._self, this._then);

  final _ProxiesStyleProps _self;
  final $Res Function(_ProxiesStyleProps) _then;

/// Create a copy of ProxiesStyleProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? sortType = null,Object? layout = null,Object? listHeaderStyle = null,Object? iconStyle = null,Object? iconSource = null,Object? cardType = null,Object? hideUnavailable = null,}) {
  return _then(_ProxiesStyleProps(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ProxiesType,sortType: null == sortType ? _self.sortType : sortType // ignore: cast_nullable_to_non_nullable
as ProxiesSortType,layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as ProxiesLayout,listHeaderStyle: null == listHeaderStyle ? _self.listHeaderStyle : listHeaderStyle // ignore: cast_nullable_to_non_nullable
as ProxiesListHeaderStyle,iconStyle: null == iconStyle ? _self.iconStyle : iconStyle // ignore: cast_nullable_to_non_nullable
as ProxiesIconStyle,iconSource: null == iconSource ? _self.iconSource : iconSource // ignore: cast_nullable_to_non_nullable
as ProxiesIconSource,cardType: null == cardType ? _self.cardType : cardType // ignore: cast_nullable_to_non_nullable
as ProxyCardType,hideUnavailable: null == hideUnavailable ? _self.hideUnavailable : hideUnavailable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TextScale {

 bool get enable; double get scale;
/// Create a copy of TextScale
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextScaleCopyWith<TextScale> get copyWith => _$TextScaleCopyWithImpl<TextScale>(this as TextScale, _$identity);

  /// Serializes this TextScale to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TextScale&&(identical(other.enable, enable) || other.enable == enable)&&(identical(other.scale, scale) || other.scale == scale));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enable,scale);

@override
String toString() {
  return 'TextScale(enable: $enable, scale: $scale)';
}


}

/// @nodoc
abstract mixin class $TextScaleCopyWith<$Res>  {
  factory $TextScaleCopyWith(TextScale value, $Res Function(TextScale) _then) = _$TextScaleCopyWithImpl;
@useResult
$Res call({
 bool enable, double scale
});




}
/// @nodoc
class _$TextScaleCopyWithImpl<$Res>
    implements $TextScaleCopyWith<$Res> {
  _$TextScaleCopyWithImpl(this._self, this._then);

  final TextScale _self;
  final $Res Function(TextScale) _then;

/// Create a copy of TextScale
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enable = null,Object? scale = null,}) {
  return _then(_self.copyWith(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [TextScale].
extension TextScalePatterns on TextScale {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TextScale value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TextScale() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TextScale value)  $default,){
final _that = this;
switch (_that) {
case _TextScale():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TextScale value)?  $default,){
final _that = this;
switch (_that) {
case _TextScale() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enable,  double scale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TextScale() when $default != null:
return $default(_that.enable,_that.scale);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enable,  double scale)  $default,) {final _that = this;
switch (_that) {
case _TextScale():
return $default(_that.enable,_that.scale);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enable,  double scale)?  $default,) {final _that = this;
switch (_that) {
case _TextScale() when $default != null:
return $default(_that.enable,_that.scale);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TextScale implements TextScale {
  const _TextScale({this.enable = false, this.scale = 1.0});
  factory _TextScale.fromJson(Map<String, dynamic> json) => _$TextScaleFromJson(json);

@override@JsonKey() final  bool enable;
@override@JsonKey() final  double scale;

/// Create a copy of TextScale
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TextScaleCopyWith<_TextScale> get copyWith => __$TextScaleCopyWithImpl<_TextScale>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TextScaleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TextScale&&(identical(other.enable, enable) || other.enable == enable)&&(identical(other.scale, scale) || other.scale == scale));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enable,scale);

@override
String toString() {
  return 'TextScale(enable: $enable, scale: $scale)';
}


}

/// @nodoc
abstract mixin class _$TextScaleCopyWith<$Res> implements $TextScaleCopyWith<$Res> {
  factory _$TextScaleCopyWith(_TextScale value, $Res Function(_TextScale) _then) = __$TextScaleCopyWithImpl;
@override @useResult
$Res call({
 bool enable, double scale
});




}
/// @nodoc
class __$TextScaleCopyWithImpl<$Res>
    implements _$TextScaleCopyWith<$Res> {
  __$TextScaleCopyWithImpl(this._self, this._then);

  final _TextScale _self;
  final $Res Function(_TextScale) _then;

/// Create a copy of TextScale
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enable = null,Object? scale = null,}) {
  return _then(_TextScale(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$ThemeProps {

 int? get primaryColor; List<int> get primaryColors;@JsonKey(unknownEnumValue: ThemeMode.system) ThemeMode get themeMode;@JsonKey(unknownEnumValue: DynamicSchemeVariant.content) DynamicSchemeVariant get schemeVariant; bool get pureBlack; bool get monochromeTrayIcon; bool get predictiveBack; TextScale get textScale;
/// Create a copy of ThemeProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThemePropsCopyWith<ThemeProps> get copyWith => _$ThemePropsCopyWithImpl<ThemeProps>(this as ThemeProps, _$identity);

  /// Serializes this ThemeProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThemeProps&&(identical(other.primaryColor, primaryColor) || other.primaryColor == primaryColor)&&const DeepCollectionEquality().equals(other.primaryColors, primaryColors)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.schemeVariant, schemeVariant) || other.schemeVariant == schemeVariant)&&(identical(other.pureBlack, pureBlack) || other.pureBlack == pureBlack)&&(identical(other.monochromeTrayIcon, monochromeTrayIcon) || other.monochromeTrayIcon == monochromeTrayIcon)&&(identical(other.predictiveBack, predictiveBack) || other.predictiveBack == predictiveBack)&&(identical(other.textScale, textScale) || other.textScale == textScale));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,primaryColor,const DeepCollectionEquality().hash(primaryColors),themeMode,schemeVariant,pureBlack,monochromeTrayIcon,predictiveBack,textScale);

@override
String toString() {
  return 'ThemeProps(primaryColor: $primaryColor, primaryColors: $primaryColors, themeMode: $themeMode, schemeVariant: $schemeVariant, pureBlack: $pureBlack, monochromeTrayIcon: $monochromeTrayIcon, predictiveBack: $predictiveBack, textScale: $textScale)';
}


}

/// @nodoc
abstract mixin class $ThemePropsCopyWith<$Res>  {
  factory $ThemePropsCopyWith(ThemeProps value, $Res Function(ThemeProps) _then) = _$ThemePropsCopyWithImpl;
@useResult
$Res call({
 int? primaryColor, List<int> primaryColors,@JsonKey(unknownEnumValue: ThemeMode.system) ThemeMode themeMode,@JsonKey(unknownEnumValue: DynamicSchemeVariant.content) DynamicSchemeVariant schemeVariant, bool pureBlack, bool monochromeTrayIcon, bool predictiveBack, TextScale textScale
});


$TextScaleCopyWith<$Res> get textScale;

}
/// @nodoc
class _$ThemePropsCopyWithImpl<$Res>
    implements $ThemePropsCopyWith<$Res> {
  _$ThemePropsCopyWithImpl(this._self, this._then);

  final ThemeProps _self;
  final $Res Function(ThemeProps) _then;

/// Create a copy of ThemeProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? primaryColor = freezed,Object? primaryColors = null,Object? themeMode = null,Object? schemeVariant = null,Object? pureBlack = null,Object? monochromeTrayIcon = null,Object? predictiveBack = null,Object? textScale = null,}) {
  return _then(_self.copyWith(
primaryColor: freezed == primaryColor ? _self.primaryColor : primaryColor // ignore: cast_nullable_to_non_nullable
as int?,primaryColors: null == primaryColors ? _self.primaryColors : primaryColors // ignore: cast_nullable_to_non_nullable
as List<int>,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemeMode,schemeVariant: null == schemeVariant ? _self.schemeVariant : schemeVariant // ignore: cast_nullable_to_non_nullable
as DynamicSchemeVariant,pureBlack: null == pureBlack ? _self.pureBlack : pureBlack // ignore: cast_nullable_to_non_nullable
as bool,monochromeTrayIcon: null == monochromeTrayIcon ? _self.monochromeTrayIcon : monochromeTrayIcon // ignore: cast_nullable_to_non_nullable
as bool,predictiveBack: null == predictiveBack ? _self.predictiveBack : predictiveBack // ignore: cast_nullable_to_non_nullable
as bool,textScale: null == textScale ? _self.textScale : textScale // ignore: cast_nullable_to_non_nullable
as TextScale,
  ));
}
/// Create a copy of ThemeProps
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TextScaleCopyWith<$Res> get textScale {
  
  return $TextScaleCopyWith<$Res>(_self.textScale, (value) {
    return _then(_self.copyWith(textScale: value));
  });
}
}


/// Adds pattern-matching-related methods to [ThemeProps].
extension ThemePropsPatterns on ThemeProps {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThemeProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThemeProps() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThemeProps value)  $default,){
final _that = this;
switch (_that) {
case _ThemeProps():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThemeProps value)?  $default,){
final _that = this;
switch (_that) {
case _ThemeProps() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? primaryColor,  List<int> primaryColors, @JsonKey(unknownEnumValue: ThemeMode.system)  ThemeMode themeMode, @JsonKey(unknownEnumValue: DynamicSchemeVariant.content)  DynamicSchemeVariant schemeVariant,  bool pureBlack,  bool monochromeTrayIcon,  bool predictiveBack,  TextScale textScale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThemeProps() when $default != null:
return $default(_that.primaryColor,_that.primaryColors,_that.themeMode,_that.schemeVariant,_that.pureBlack,_that.monochromeTrayIcon,_that.predictiveBack,_that.textScale);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? primaryColor,  List<int> primaryColors, @JsonKey(unknownEnumValue: ThemeMode.system)  ThemeMode themeMode, @JsonKey(unknownEnumValue: DynamicSchemeVariant.content)  DynamicSchemeVariant schemeVariant,  bool pureBlack,  bool monochromeTrayIcon,  bool predictiveBack,  TextScale textScale)  $default,) {final _that = this;
switch (_that) {
case _ThemeProps():
return $default(_that.primaryColor,_that.primaryColors,_that.themeMode,_that.schemeVariant,_that.pureBlack,_that.monochromeTrayIcon,_that.predictiveBack,_that.textScale);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? primaryColor,  List<int> primaryColors, @JsonKey(unknownEnumValue: ThemeMode.system)  ThemeMode themeMode, @JsonKey(unknownEnumValue: DynamicSchemeVariant.content)  DynamicSchemeVariant schemeVariant,  bool pureBlack,  bool monochromeTrayIcon,  bool predictiveBack,  TextScale textScale)?  $default,) {final _that = this;
switch (_that) {
case _ThemeProps() when $default != null:
return $default(_that.primaryColor,_that.primaryColors,_that.themeMode,_that.schemeVariant,_that.pureBlack,_that.monochromeTrayIcon,_that.predictiveBack,_that.textScale);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ThemeProps implements ThemeProps {
  const _ThemeProps({this.primaryColor, final  List<int> primaryColors = defaultPrimaryColors, @JsonKey(unknownEnumValue: ThemeMode.system) this.themeMode = ThemeMode.system, @JsonKey(unknownEnumValue: DynamicSchemeVariant.content) this.schemeVariant = DynamicSchemeVariant.content, this.pureBlack = false, this.monochromeTrayIcon = true, this.predictiveBack = true, this.textScale = const TextScale()}): _primaryColors = primaryColors;
  factory _ThemeProps.fromJson(Map<String, dynamic> json) => _$ThemePropsFromJson(json);

@override final  int? primaryColor;
 final  List<int> _primaryColors;
@override@JsonKey() List<int> get primaryColors {
  if (_primaryColors is EqualUnmodifiableListView) return _primaryColors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_primaryColors);
}

@override@JsonKey(unknownEnumValue: ThemeMode.system) final  ThemeMode themeMode;
@override@JsonKey(unknownEnumValue: DynamicSchemeVariant.content) final  DynamicSchemeVariant schemeVariant;
@override@JsonKey() final  bool pureBlack;
@override@JsonKey() final  bool monochromeTrayIcon;
@override@JsonKey() final  bool predictiveBack;
@override@JsonKey() final  TextScale textScale;

/// Create a copy of ThemeProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThemePropsCopyWith<_ThemeProps> get copyWith => __$ThemePropsCopyWithImpl<_ThemeProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ThemePropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThemeProps&&(identical(other.primaryColor, primaryColor) || other.primaryColor == primaryColor)&&const DeepCollectionEquality().equals(other._primaryColors, _primaryColors)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.schemeVariant, schemeVariant) || other.schemeVariant == schemeVariant)&&(identical(other.pureBlack, pureBlack) || other.pureBlack == pureBlack)&&(identical(other.monochromeTrayIcon, monochromeTrayIcon) || other.monochromeTrayIcon == monochromeTrayIcon)&&(identical(other.predictiveBack, predictiveBack) || other.predictiveBack == predictiveBack)&&(identical(other.textScale, textScale) || other.textScale == textScale));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,primaryColor,const DeepCollectionEquality().hash(_primaryColors),themeMode,schemeVariant,pureBlack,monochromeTrayIcon,predictiveBack,textScale);

@override
String toString() {
  return 'ThemeProps(primaryColor: $primaryColor, primaryColors: $primaryColors, themeMode: $themeMode, schemeVariant: $schemeVariant, pureBlack: $pureBlack, monochromeTrayIcon: $monochromeTrayIcon, predictiveBack: $predictiveBack, textScale: $textScale)';
}


}

/// @nodoc
abstract mixin class _$ThemePropsCopyWith<$Res> implements $ThemePropsCopyWith<$Res> {
  factory _$ThemePropsCopyWith(_ThemeProps value, $Res Function(_ThemeProps) _then) = __$ThemePropsCopyWithImpl;
@override @useResult
$Res call({
 int? primaryColor, List<int> primaryColors,@JsonKey(unknownEnumValue: ThemeMode.system) ThemeMode themeMode,@JsonKey(unknownEnumValue: DynamicSchemeVariant.content) DynamicSchemeVariant schemeVariant, bool pureBlack, bool monochromeTrayIcon, bool predictiveBack, TextScale textScale
});


@override $TextScaleCopyWith<$Res> get textScale;

}
/// @nodoc
class __$ThemePropsCopyWithImpl<$Res>
    implements _$ThemePropsCopyWith<$Res> {
  __$ThemePropsCopyWithImpl(this._self, this._then);

  final _ThemeProps _self;
  final $Res Function(_ThemeProps) _then;

/// Create a copy of ThemeProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? primaryColor = freezed,Object? primaryColors = null,Object? themeMode = null,Object? schemeVariant = null,Object? pureBlack = null,Object? monochromeTrayIcon = null,Object? predictiveBack = null,Object? textScale = null,}) {
  return _then(_ThemeProps(
primaryColor: freezed == primaryColor ? _self.primaryColor : primaryColor // ignore: cast_nullable_to_non_nullable
as int?,primaryColors: null == primaryColors ? _self._primaryColors : primaryColors // ignore: cast_nullable_to_non_nullable
as List<int>,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemeMode,schemeVariant: null == schemeVariant ? _self.schemeVariant : schemeVariant // ignore: cast_nullable_to_non_nullable
as DynamicSchemeVariant,pureBlack: null == pureBlack ? _self.pureBlack : pureBlack // ignore: cast_nullable_to_non_nullable
as bool,monochromeTrayIcon: null == monochromeTrayIcon ? _self.monochromeTrayIcon : monochromeTrayIcon // ignore: cast_nullable_to_non_nullable
as bool,predictiveBack: null == predictiveBack ? _self.predictiveBack : predictiveBack // ignore: cast_nullable_to_non_nullable
as bool,textScale: null == textScale ? _self.textScale : textScale // ignore: cast_nullable_to_non_nullable
as TextScale,
  ));
}

/// Create a copy of ThemeProps
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TextScaleCopyWith<$Res> get textScale {
  
  return $TextScaleCopyWith<$Res>(_self.textScale, (value) {
    return _then(_self.copyWith(textScale: value));
  });
}
}


/// @nodoc
mixin _$Config {

 int? get currentProfileId; bool get overrideDns; List<HotKeyAction> get hotKeyActions;@JsonKey(fromJson: AppSettingProps.safeFromJson) AppSettingProps get appSettingProps; DAVProps? get davProps; NetworkProps get networkProps; VpnProps get vpnProps;@JsonKey(fromJson: ThemeProps.safeFromJson) ThemeProps get themeProps; ProxiesStyleProps get proxiesStyleProps; WindowProps get windowProps; PatchClashConfig get patchClashConfig; List<String> get excludeSSIDs; bool get alwaysOn;
/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConfigCopyWith<Config> get copyWith => _$ConfigCopyWithImpl<Config>(this as Config, _$identity);

  /// Serializes this Config to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Config&&(identical(other.currentProfileId, currentProfileId) || other.currentProfileId == currentProfileId)&&(identical(other.overrideDns, overrideDns) || other.overrideDns == overrideDns)&&const DeepCollectionEquality().equals(other.hotKeyActions, hotKeyActions)&&(identical(other.appSettingProps, appSettingProps) || other.appSettingProps == appSettingProps)&&(identical(other.davProps, davProps) || other.davProps == davProps)&&(identical(other.networkProps, networkProps) || other.networkProps == networkProps)&&(identical(other.vpnProps, vpnProps) || other.vpnProps == vpnProps)&&(identical(other.themeProps, themeProps) || other.themeProps == themeProps)&&(identical(other.proxiesStyleProps, proxiesStyleProps) || other.proxiesStyleProps == proxiesStyleProps)&&(identical(other.windowProps, windowProps) || other.windowProps == windowProps)&&(identical(other.patchClashConfig, patchClashConfig) || other.patchClashConfig == patchClashConfig)&&const DeepCollectionEquality().equals(other.excludeSSIDs, excludeSSIDs)&&(identical(other.alwaysOn, alwaysOn) || other.alwaysOn == alwaysOn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,currentProfileId,overrideDns,const DeepCollectionEquality().hash(hotKeyActions),appSettingProps,davProps,networkProps,vpnProps,themeProps,proxiesStyleProps,windowProps,patchClashConfig,const DeepCollectionEquality().hash(excludeSSIDs),alwaysOn);

@override
String toString() {
  return 'Config(currentProfileId: $currentProfileId, overrideDns: $overrideDns, hotKeyActions: $hotKeyActions, appSettingProps: $appSettingProps, davProps: $davProps, networkProps: $networkProps, vpnProps: $vpnProps, themeProps: $themeProps, proxiesStyleProps: $proxiesStyleProps, windowProps: $windowProps, patchClashConfig: $patchClashConfig, excludeSSIDs: $excludeSSIDs, alwaysOn: $alwaysOn)';
}


}

/// @nodoc
abstract mixin class $ConfigCopyWith<$Res>  {
  factory $ConfigCopyWith(Config value, $Res Function(Config) _then) = _$ConfigCopyWithImpl;
@useResult
$Res call({
 int? currentProfileId, bool overrideDns, List<HotKeyAction> hotKeyActions,@JsonKey(fromJson: AppSettingProps.safeFromJson) AppSettingProps appSettingProps, DAVProps? davProps, NetworkProps networkProps, VpnProps vpnProps,@JsonKey(fromJson: ThemeProps.safeFromJson) ThemeProps themeProps, ProxiesStyleProps proxiesStyleProps, WindowProps windowProps, PatchClashConfig patchClashConfig, List<String> excludeSSIDs, bool alwaysOn
});


$AppSettingPropsCopyWith<$Res> get appSettingProps;$DAVPropsCopyWith<$Res>? get davProps;$NetworkPropsCopyWith<$Res> get networkProps;$VpnPropsCopyWith<$Res> get vpnProps;$ThemePropsCopyWith<$Res> get themeProps;$ProxiesStylePropsCopyWith<$Res> get proxiesStyleProps;$WindowPropsCopyWith<$Res> get windowProps;$PatchClashConfigCopyWith<$Res> get patchClashConfig;

}
/// @nodoc
class _$ConfigCopyWithImpl<$Res>
    implements $ConfigCopyWith<$Res> {
  _$ConfigCopyWithImpl(this._self, this._then);

  final Config _self;
  final $Res Function(Config) _then;

/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentProfileId = freezed,Object? overrideDns = null,Object? hotKeyActions = null,Object? appSettingProps = null,Object? davProps = freezed,Object? networkProps = null,Object? vpnProps = null,Object? themeProps = null,Object? proxiesStyleProps = null,Object? windowProps = null,Object? patchClashConfig = null,Object? excludeSSIDs = null,Object? alwaysOn = null,}) {
  return _then(_self.copyWith(
currentProfileId: freezed == currentProfileId ? _self.currentProfileId : currentProfileId // ignore: cast_nullable_to_non_nullable
as int?,overrideDns: null == overrideDns ? _self.overrideDns : overrideDns // ignore: cast_nullable_to_non_nullable
as bool,hotKeyActions: null == hotKeyActions ? _self.hotKeyActions : hotKeyActions // ignore: cast_nullable_to_non_nullable
as List<HotKeyAction>,appSettingProps: null == appSettingProps ? _self.appSettingProps : appSettingProps // ignore: cast_nullable_to_non_nullable
as AppSettingProps,davProps: freezed == davProps ? _self.davProps : davProps // ignore: cast_nullable_to_non_nullable
as DAVProps?,networkProps: null == networkProps ? _self.networkProps : networkProps // ignore: cast_nullable_to_non_nullable
as NetworkProps,vpnProps: null == vpnProps ? _self.vpnProps : vpnProps // ignore: cast_nullable_to_non_nullable
as VpnProps,themeProps: null == themeProps ? _self.themeProps : themeProps // ignore: cast_nullable_to_non_nullable
as ThemeProps,proxiesStyleProps: null == proxiesStyleProps ? _self.proxiesStyleProps : proxiesStyleProps // ignore: cast_nullable_to_non_nullable
as ProxiesStyleProps,windowProps: null == windowProps ? _self.windowProps : windowProps // ignore: cast_nullable_to_non_nullable
as WindowProps,patchClashConfig: null == patchClashConfig ? _self.patchClashConfig : patchClashConfig // ignore: cast_nullable_to_non_nullable
as PatchClashConfig,excludeSSIDs: null == excludeSSIDs ? _self.excludeSSIDs : excludeSSIDs // ignore: cast_nullable_to_non_nullable
as List<String>,alwaysOn: null == alwaysOn ? _self.alwaysOn : alwaysOn // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppSettingPropsCopyWith<$Res> get appSettingProps {
  
  return $AppSettingPropsCopyWith<$Res>(_self.appSettingProps, (value) {
    return _then(_self.copyWith(appSettingProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DAVPropsCopyWith<$Res>? get davProps {
    if (_self.davProps == null) {
    return null;
  }

  return $DAVPropsCopyWith<$Res>(_self.davProps!, (value) {
    return _then(_self.copyWith(davProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NetworkPropsCopyWith<$Res> get networkProps {
  
  return $NetworkPropsCopyWith<$Res>(_self.networkProps, (value) {
    return _then(_self.copyWith(networkProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VpnPropsCopyWith<$Res> get vpnProps {
  
  return $VpnPropsCopyWith<$Res>(_self.vpnProps, (value) {
    return _then(_self.copyWith(vpnProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThemePropsCopyWith<$Res> get themeProps {
  
  return $ThemePropsCopyWith<$Res>(_self.themeProps, (value) {
    return _then(_self.copyWith(themeProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProxiesStylePropsCopyWith<$Res> get proxiesStyleProps {
  
  return $ProxiesStylePropsCopyWith<$Res>(_self.proxiesStyleProps, (value) {
    return _then(_self.copyWith(proxiesStyleProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindowPropsCopyWith<$Res> get windowProps {
  
  return $WindowPropsCopyWith<$Res>(_self.windowProps, (value) {
    return _then(_self.copyWith(windowProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PatchClashConfigCopyWith<$Res> get patchClashConfig {
  
  return $PatchClashConfigCopyWith<$Res>(_self.patchClashConfig, (value) {
    return _then(_self.copyWith(patchClashConfig: value));
  });
}
}


/// Adds pattern-matching-related methods to [Config].
extension ConfigPatterns on Config {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Config value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Config() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Config value)  $default,){
final _that = this;
switch (_that) {
case _Config():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Config value)?  $default,){
final _that = this;
switch (_that) {
case _Config() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? currentProfileId,  bool overrideDns,  List<HotKeyAction> hotKeyActions, @JsonKey(fromJson: AppSettingProps.safeFromJson)  AppSettingProps appSettingProps,  DAVProps? davProps,  NetworkProps networkProps,  VpnProps vpnProps, @JsonKey(fromJson: ThemeProps.safeFromJson)  ThemeProps themeProps,  ProxiesStyleProps proxiesStyleProps,  WindowProps windowProps,  PatchClashConfig patchClashConfig,  List<String> excludeSSIDs,  bool alwaysOn)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Config() when $default != null:
return $default(_that.currentProfileId,_that.overrideDns,_that.hotKeyActions,_that.appSettingProps,_that.davProps,_that.networkProps,_that.vpnProps,_that.themeProps,_that.proxiesStyleProps,_that.windowProps,_that.patchClashConfig,_that.excludeSSIDs,_that.alwaysOn);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? currentProfileId,  bool overrideDns,  List<HotKeyAction> hotKeyActions, @JsonKey(fromJson: AppSettingProps.safeFromJson)  AppSettingProps appSettingProps,  DAVProps? davProps,  NetworkProps networkProps,  VpnProps vpnProps, @JsonKey(fromJson: ThemeProps.safeFromJson)  ThemeProps themeProps,  ProxiesStyleProps proxiesStyleProps,  WindowProps windowProps,  PatchClashConfig patchClashConfig,  List<String> excludeSSIDs,  bool alwaysOn)  $default,) {final _that = this;
switch (_that) {
case _Config():
return $default(_that.currentProfileId,_that.overrideDns,_that.hotKeyActions,_that.appSettingProps,_that.davProps,_that.networkProps,_that.vpnProps,_that.themeProps,_that.proxiesStyleProps,_that.windowProps,_that.patchClashConfig,_that.excludeSSIDs,_that.alwaysOn);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? currentProfileId,  bool overrideDns,  List<HotKeyAction> hotKeyActions, @JsonKey(fromJson: AppSettingProps.safeFromJson)  AppSettingProps appSettingProps,  DAVProps? davProps,  NetworkProps networkProps,  VpnProps vpnProps, @JsonKey(fromJson: ThemeProps.safeFromJson)  ThemeProps themeProps,  ProxiesStyleProps proxiesStyleProps,  WindowProps windowProps,  PatchClashConfig patchClashConfig,  List<String> excludeSSIDs,  bool alwaysOn)?  $default,) {final _that = this;
switch (_that) {
case _Config() when $default != null:
return $default(_that.currentProfileId,_that.overrideDns,_that.hotKeyActions,_that.appSettingProps,_that.davProps,_that.networkProps,_that.vpnProps,_that.themeProps,_that.proxiesStyleProps,_that.windowProps,_that.patchClashConfig,_that.excludeSSIDs,_that.alwaysOn);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Config implements Config {
  const _Config({this.currentProfileId, this.overrideDns = false, final  List<HotKeyAction> hotKeyActions = const [], @JsonKey(fromJson: AppSettingProps.safeFromJson) this.appSettingProps = defaultAppSettingProps, this.davProps, this.networkProps = defaultNetworkProps, this.vpnProps = defaultVpnProps, @JsonKey(fromJson: ThemeProps.safeFromJson) required this.themeProps, this.proxiesStyleProps = defaultProxiesStyleProps, this.windowProps = defaultWindowProps, this.patchClashConfig = defaultClashConfig, final  List<String> excludeSSIDs = const [], this.alwaysOn = false}): _hotKeyActions = hotKeyActions,_excludeSSIDs = excludeSSIDs;
  factory _Config.fromJson(Map<String, dynamic> json) => _$ConfigFromJson(json);

@override final  int? currentProfileId;
@override@JsonKey() final  bool overrideDns;
 final  List<HotKeyAction> _hotKeyActions;
@override@JsonKey() List<HotKeyAction> get hotKeyActions {
  if (_hotKeyActions is EqualUnmodifiableListView) return _hotKeyActions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hotKeyActions);
}

@override@JsonKey(fromJson: AppSettingProps.safeFromJson) final  AppSettingProps appSettingProps;
@override final  DAVProps? davProps;
@override@JsonKey() final  NetworkProps networkProps;
@override@JsonKey() final  VpnProps vpnProps;
@override@JsonKey(fromJson: ThemeProps.safeFromJson) final  ThemeProps themeProps;
@override@JsonKey() final  ProxiesStyleProps proxiesStyleProps;
@override@JsonKey() final  WindowProps windowProps;
@override@JsonKey() final  PatchClashConfig patchClashConfig;
 final  List<String> _excludeSSIDs;
@override@JsonKey() List<String> get excludeSSIDs {
  if (_excludeSSIDs is EqualUnmodifiableListView) return _excludeSSIDs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_excludeSSIDs);
}

@override@JsonKey() final  bool alwaysOn;

/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConfigCopyWith<_Config> get copyWith => __$ConfigCopyWithImpl<_Config>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Config&&(identical(other.currentProfileId, currentProfileId) || other.currentProfileId == currentProfileId)&&(identical(other.overrideDns, overrideDns) || other.overrideDns == overrideDns)&&const DeepCollectionEquality().equals(other._hotKeyActions, _hotKeyActions)&&(identical(other.appSettingProps, appSettingProps) || other.appSettingProps == appSettingProps)&&(identical(other.davProps, davProps) || other.davProps == davProps)&&(identical(other.networkProps, networkProps) || other.networkProps == networkProps)&&(identical(other.vpnProps, vpnProps) || other.vpnProps == vpnProps)&&(identical(other.themeProps, themeProps) || other.themeProps == themeProps)&&(identical(other.proxiesStyleProps, proxiesStyleProps) || other.proxiesStyleProps == proxiesStyleProps)&&(identical(other.windowProps, windowProps) || other.windowProps == windowProps)&&(identical(other.patchClashConfig, patchClashConfig) || other.patchClashConfig == patchClashConfig)&&const DeepCollectionEquality().equals(other._excludeSSIDs, _excludeSSIDs)&&(identical(other.alwaysOn, alwaysOn) || other.alwaysOn == alwaysOn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,currentProfileId,overrideDns,const DeepCollectionEquality().hash(_hotKeyActions),appSettingProps,davProps,networkProps,vpnProps,themeProps,proxiesStyleProps,windowProps,patchClashConfig,const DeepCollectionEquality().hash(_excludeSSIDs),alwaysOn);

@override
String toString() {
  return 'Config(currentProfileId: $currentProfileId, overrideDns: $overrideDns, hotKeyActions: $hotKeyActions, appSettingProps: $appSettingProps, davProps: $davProps, networkProps: $networkProps, vpnProps: $vpnProps, themeProps: $themeProps, proxiesStyleProps: $proxiesStyleProps, windowProps: $windowProps, patchClashConfig: $patchClashConfig, excludeSSIDs: $excludeSSIDs, alwaysOn: $alwaysOn)';
}


}

/// @nodoc
abstract mixin class _$ConfigCopyWith<$Res> implements $ConfigCopyWith<$Res> {
  factory _$ConfigCopyWith(_Config value, $Res Function(_Config) _then) = __$ConfigCopyWithImpl;
@override @useResult
$Res call({
 int? currentProfileId, bool overrideDns, List<HotKeyAction> hotKeyActions,@JsonKey(fromJson: AppSettingProps.safeFromJson) AppSettingProps appSettingProps, DAVProps? davProps, NetworkProps networkProps, VpnProps vpnProps,@JsonKey(fromJson: ThemeProps.safeFromJson) ThemeProps themeProps, ProxiesStyleProps proxiesStyleProps, WindowProps windowProps, PatchClashConfig patchClashConfig, List<String> excludeSSIDs, bool alwaysOn
});


@override $AppSettingPropsCopyWith<$Res> get appSettingProps;@override $DAVPropsCopyWith<$Res>? get davProps;@override $NetworkPropsCopyWith<$Res> get networkProps;@override $VpnPropsCopyWith<$Res> get vpnProps;@override $ThemePropsCopyWith<$Res> get themeProps;@override $ProxiesStylePropsCopyWith<$Res> get proxiesStyleProps;@override $WindowPropsCopyWith<$Res> get windowProps;@override $PatchClashConfigCopyWith<$Res> get patchClashConfig;

}
/// @nodoc
class __$ConfigCopyWithImpl<$Res>
    implements _$ConfigCopyWith<$Res> {
  __$ConfigCopyWithImpl(this._self, this._then);

  final _Config _self;
  final $Res Function(_Config) _then;

/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentProfileId = freezed,Object? overrideDns = null,Object? hotKeyActions = null,Object? appSettingProps = null,Object? davProps = freezed,Object? networkProps = null,Object? vpnProps = null,Object? themeProps = null,Object? proxiesStyleProps = null,Object? windowProps = null,Object? patchClashConfig = null,Object? excludeSSIDs = null,Object? alwaysOn = null,}) {
  return _then(_Config(
currentProfileId: freezed == currentProfileId ? _self.currentProfileId : currentProfileId // ignore: cast_nullable_to_non_nullable
as int?,overrideDns: null == overrideDns ? _self.overrideDns : overrideDns // ignore: cast_nullable_to_non_nullable
as bool,hotKeyActions: null == hotKeyActions ? _self._hotKeyActions : hotKeyActions // ignore: cast_nullable_to_non_nullable
as List<HotKeyAction>,appSettingProps: null == appSettingProps ? _self.appSettingProps : appSettingProps // ignore: cast_nullable_to_non_nullable
as AppSettingProps,davProps: freezed == davProps ? _self.davProps : davProps // ignore: cast_nullable_to_non_nullable
as DAVProps?,networkProps: null == networkProps ? _self.networkProps : networkProps // ignore: cast_nullable_to_non_nullable
as NetworkProps,vpnProps: null == vpnProps ? _self.vpnProps : vpnProps // ignore: cast_nullable_to_non_nullable
as VpnProps,themeProps: null == themeProps ? _self.themeProps : themeProps // ignore: cast_nullable_to_non_nullable
as ThemeProps,proxiesStyleProps: null == proxiesStyleProps ? _self.proxiesStyleProps : proxiesStyleProps // ignore: cast_nullable_to_non_nullable
as ProxiesStyleProps,windowProps: null == windowProps ? _self.windowProps : windowProps // ignore: cast_nullable_to_non_nullable
as WindowProps,patchClashConfig: null == patchClashConfig ? _self.patchClashConfig : patchClashConfig // ignore: cast_nullable_to_non_nullable
as PatchClashConfig,excludeSSIDs: null == excludeSSIDs ? _self._excludeSSIDs : excludeSSIDs // ignore: cast_nullable_to_non_nullable
as List<String>,alwaysOn: null == alwaysOn ? _self.alwaysOn : alwaysOn // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppSettingPropsCopyWith<$Res> get appSettingProps {
  
  return $AppSettingPropsCopyWith<$Res>(_self.appSettingProps, (value) {
    return _then(_self.copyWith(appSettingProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DAVPropsCopyWith<$Res>? get davProps {
    if (_self.davProps == null) {
    return null;
  }

  return $DAVPropsCopyWith<$Res>(_self.davProps!, (value) {
    return _then(_self.copyWith(davProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NetworkPropsCopyWith<$Res> get networkProps {
  
  return $NetworkPropsCopyWith<$Res>(_self.networkProps, (value) {
    return _then(_self.copyWith(networkProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VpnPropsCopyWith<$Res> get vpnProps {
  
  return $VpnPropsCopyWith<$Res>(_self.vpnProps, (value) {
    return _then(_self.copyWith(vpnProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThemePropsCopyWith<$Res> get themeProps {
  
  return $ThemePropsCopyWith<$Res>(_self.themeProps, (value) {
    return _then(_self.copyWith(themeProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProxiesStylePropsCopyWith<$Res> get proxiesStyleProps {
  
  return $ProxiesStylePropsCopyWith<$Res>(_self.proxiesStyleProps, (value) {
    return _then(_self.copyWith(proxiesStyleProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindowPropsCopyWith<$Res> get windowProps {
  
  return $WindowPropsCopyWith<$Res>(_self.windowProps, (value) {
    return _then(_self.copyWith(windowProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PatchClashConfigCopyWith<$Res> get patchClashConfig {
  
  return $PatchClashConfigCopyWith<$Res>(_self.patchClashConfig, (value) {
    return _then(_self.copyWith(patchClashConfig: value));
  });
}
}

// dart format on

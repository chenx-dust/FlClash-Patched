import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tvLayoutProvider = Provider<bool>((ref) {
  final tvMode = ref.watch(appSettingProvider.select((state) => state.tvMode));
  return system.isTV || tvMode;
});

Widget withTvLayout(
  BuildContext context, {
  bool? isTV,
  required Widget Function(BuildContext context, bool tvLayout) builder,
}) {
  final override = isTV;
  if (override != null) {
    return builder(context, override);
  }
  if (!_hasProviderScope(context)) {
    return builder(context, system.isTV);
  }
  return Consumer(
    builder: (context, ref, _) => builder(context, ref.watch(tvLayoutProvider)),
  );
}

bool _hasProviderScope(BuildContext context) {
  try {
    ProviderScope.containerOf(context, listen: false);
  } on StateError {
    // containerOf throws when this subtree has no scope.
    return false;
  }
  return true;
}

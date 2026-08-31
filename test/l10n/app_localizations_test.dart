import 'package:fl_clash/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('load resolves accessors for every supported locale', () async {
    for (final locale in AppLocalizations.delegate.supportedLocales) {
      final appLocalizations = await AppLocalizations.load(locale);

      expect(AppLocalizations.current, same(appLocalizations));
      expect(appLocalizations.dashboard, isNotEmpty);
      expect(appLocalizations.proxies, isNotEmpty);
      expect(appLocalizations.settings, isNotEmpty);
      expect(appLocalizations.hoursCount(2), contains('2'));
      expect(appLocalizations.secondsCount(30), contains('30'));
      expect(appLocalizations.geoUpdated('geoip'), contains('geoip'));
      expect(appLocalizations.desc.toLowerCase(), contains('mihomo'));
      expect(appLocalizations.highPriorityAutoLaunch, isNotEmpty);
      expect(appLocalizations.monochromeTrayIcon, isNotEmpty);
      expect(appLocalizations.promptCloseConnections, isNotEmpty);
      expect(appLocalizations.captureDns, isNotEmpty);
      expect(appLocalizations.networkingDesc, isNotEmpty);
    }
  });

  test('fork capabilities are translated in Japanese and Russian', () async {
    final english = await AppLocalizations.load(const Locale('en'));
    final englishHighPriority = english.highPriorityAutoLaunchDesc;
    final englishNetworking = english.networkingDesc;
    for (final locale in const [Locale('ja'), Locale('ru')]) {
      final translated = await AppLocalizations.load(locale);

      expect(translated.highPriorityAutoLaunchDesc, isNot(englishHighPriority));
      expect(translated.networkingDesc, isNot(englishNetworking));
    }
  });

  test('delegate recognizes only supported locales', () {
    expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
    expect(AppLocalizations.delegate.isSupported(const Locale('fr')), isFalse);
    expect(
      AppLocalizations.delegate.shouldReload(AppLocalizations.delegate),
      isFalse,
    );
  });
}

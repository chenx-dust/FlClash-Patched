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
      expect(appLocalizations.hoursCount('2'), contains('2'));
      expect(appLocalizations.secondsCount('30'), contains('30'));
      expect(appLocalizations.geoUpdated('geoip'), contains('geoip'));
      expect(appLocalizations.confirmClearSelectedData, isNotEmpty);
      expect(appLocalizations.allData, isNotEmpty);
      expect(appLocalizations.resetSettingsData, isNotEmpty);
      expect(appLocalizations.resetProfilesAndScripts, isNotEmpty);
      expect(appLocalizations.promptCloseConnections, isNotEmpty);
      expect(appLocalizations.promptCloseConnectionsDesc, isNotEmpty);
      expect(appLocalizations.nodes, isNotEmpty);
      expect(appLocalizations.networkId, isNotEmpty);
      expect(appLocalizations.role, isNotEmpty);
      expect(appLocalizations.version, isNotEmpty);
      expect(appLocalizations.endpoints, isNotEmpty);
      expect(appLocalizations.online, isNotEmpty);
      expect(appLocalizations.offline, isNotEmpty);
      expect(appLocalizations.routes, isNotEmpty);
      expect(appLocalizations.signIn, isNotEmpty);
      expect(appLocalizations.signOut, isNotEmpty);
      expect(appLocalizations.tailscaleNodeKey, isNotEmpty);
      expect(appLocalizations.tailscaleHealthWarnings, isNotEmpty);
      expect(appLocalizations.networking, isNotEmpty);
      expect(appLocalizations.networkingDesc, isNotEmpty);
      expect(appLocalizations.networkingNoOutbounds, isNotEmpty);
      expect(appLocalizations.strictRoute, isNotEmpty);
      expect(appLocalizations.strictRouteDesc, isNotEmpty);
      expect(appLocalizations.icmpForwarding, isNotEmpty);
      expect(appLocalizations.icmpForwardingDesc, isNotEmpty);
      expect(appLocalizations.dnsHijack, isNotEmpty);
      expect(appLocalizations.dnsHijackDesc, isNotEmpty);
      expect(appLocalizations.endpointIndependentNat, isNotEmpty);
      expect(appLocalizations.endpointIndependentNatDesc, isNotEmpty);
      expect(appLocalizations.captureDns, isNotEmpty);
      expect(appLocalizations.captureDnsDesc, isNotEmpty);
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

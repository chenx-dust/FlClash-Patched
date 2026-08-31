import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/networking/tailscale.dart';
import 'package:fl_clash/views/networking/zerotier.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

typedef _NetworkingProxy = ({String name, String type});

class NetworkingView extends ConsumerStatefulWidget {
  const NetworkingView({super.key});

  @override
  ConsumerState<NetworkingView> createState() => _NetworkingViewState();
}

class _NetworkingViewState extends ConsumerState<NetworkingView>
    with WidgetsBindingObserver, ActivePollingMixin<NetworkingView> {
  final Map<String, OverlayNetworkStatus> _statuses = {};
  final Map<String, Object> _requestErrors = {};
  final Set<String> _summariesLoaded = {};
  final Set<String> _detailsLoaded = {};
  final Set<String> _loading = {};
  final Set<String> _activating = {};
  final Set<String> _loggingOut = {};
  final Set<String> _expanded = {};
  Future<void>? _summaryLoad;
  int _expansionGeneration = 0;
  bool _pageActive = false;
  bool _summaryRefreshScheduled = false;
  bool _forceSummaryRefresh = false;

  CoreController get _core => ref.read(coreHandlerProvider);

  @override
  Duration get pollInterval => const Duration(seconds: 2);

  @override
  bool get canPoll => super.canPoll && _expanded.isNotEmpty;

  bool get _isLoading =>
      _summaryLoad != null || _loading.isNotEmpty || _activating.isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pageActive = PageActivityScope.isActiveOf(context);
    if (pageActive && !_pageActive) {
      _scheduleSummaryRefresh(force: true);
    }
    _pageActive = pageActive;
  }

  @override
  Future<void> poll(PollGuard isCurrent) async {
    final proxies = _configuredProxies(ref.read(groupsProvider));
    final proxyKeys = proxies.map(_key).toSet();
    _expanded.retainWhere(proxyKeys.contains);
    if (_expanded.isEmpty) {
      stopPolling();
      return;
    }
    await _loadDetails(
      [
        for (final proxy in proxies)
          if (_expanded.contains(_key(proxy))) proxy,
      ],
      force: true,
      isCurrent: isCurrent,
    );
  }

  String _key(_NetworkingProxy proxy) => '${proxy.type}\u0000${proxy.name}';

  String _statusKey(OverlayNetworkStatus status) {
    return '${status.kind.name}\u0000${status.name}';
  }

  OverlayNetworkKind _kind(_NetworkingProxy proxy) {
    return proxy.type == 'tailscale'
        ? OverlayNetworkKind.tailscale
        : OverlayNetworkKind.zerotier;
  }

  OverlayNetworkTarget _target(
    _NetworkingProxy proxy,
    OverlayNetworkDetailLevel level,
  ) {
    return OverlayNetworkTarget(
      name: proxy.name,
      kind: _kind(proxy),
      level: level,
    );
  }

  void _scheduleSummaryRefresh({bool force = false}) {
    _forceSummaryRefresh = _forceSummaryRefresh || force;
    if (_summaryRefreshScheduled) {
      return;
    }
    _summaryRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _summaryRefreshScheduled = false;
      final shouldForce = _forceSummaryRefresh;
      _forceSummaryRefresh = false;
      if (!mounted || !PageActivityScope.isActiveOf(context)) {
        return;
      }
      unawaited(
        _loadSummaries(
          _configuredProxies(ref.read(groupsProvider)),
          force: shouldForce,
        ),
      );
    });
  }

  List<_NetworkingProxy> _configuredProxies(List<Group> groups) {
    final proxies = <String, _NetworkingProxy>{};
    for (final group in groups) {
      for (final proxy in group.all) {
        final type = proxy.type.toLowerCase();
        if (type != 'tailscale' && type != 'zerotier') {
          continue;
        }
        final item = (name: proxy.name, type: type);
        proxies[_key(item)] = item;
      }
    }
    return proxies.values.toList()..sort((a, b) {
      final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return name != 0 ? name : a.type.compareTo(b.type);
    });
  }

  Future<void> _loadSummaries(
    List<_NetworkingProxy> proxies, {
    bool force = false,
  }) async {
    final activeLoad = _summaryLoad;
    if (activeLoad != null) {
      await activeLoad;
      return;
    }
    final targets = [
      for (final proxy in proxies)
        if (force || !_summariesLoaded.contains(_key(proxy))) proxy,
    ];
    if (targets.isEmpty) {
      return;
    }
    final load = _fetchSummaries(targets);
    _summaryLoad = load;
    if (mounted) {
      setState(() {});
    }
    try {
      await load;
    } finally {
      if (identical(_summaryLoad, load)) {
        _summaryLoad = null;
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _fetchSummaries(List<_NetworkingProxy> proxies) async {
    List<OverlayNetworkStatus>? statuses;
    Object? requestError;
    try {
      statuses = await _core.getOverlayNetworkStatus(
        GetOverlayNetworkStatusParams(
          targets: [
            for (final proxy in proxies)
              _target(proxy, OverlayNetworkDetailLevel.summary),
          ],
        ),
      );
    } catch (value) {
      requestError = value;
    }
    if (!mounted) {
      return;
    }
    final statusesByKey = {
      for (final status in statuses ?? const <OverlayNetworkStatus>[])
        _statusKey(status): status,
    };
    setState(() {
      for (final proxy in proxies) {
        final key = _key(proxy);
        _summariesLoaded.add(key);
        if (requestError != null) {
          _requestErrors[key] = requestError;
          continue;
        }
        final status = statusesByKey[key];
        if (status == null) {
          _requestErrors[key] = 'Missing overlay network status';
          continue;
        }
        final previous = _statuses[key];
        _statuses[key] = previous == null
            ? status
            : status.retainDetailsFrom(previous);
        _requestErrors.remove(key);
      }
    });
  }

  Future<void> _loadDetails(
    List<_NetworkingProxy> proxies, {
    bool force = false,
    PollGuard? isCurrent,
  }) async {
    final targets = [
      for (final proxy in proxies)
        if (!_loading.contains(_key(proxy)) &&
            (force || !_detailsLoaded.contains(_key(proxy))))
          proxy,
    ];
    if (targets.isEmpty) {
      return;
    }
    setState(() {
      for (final proxy in targets) {
        _loading.add(_key(proxy));
        _requestErrors.remove(_key(proxy));
      }
    });
    List<OverlayNetworkStatus>? statuses;
    Object? requestError;
    try {
      final summaryLoad = _summaryLoad;
      if (summaryLoad != null) {
        await summaryLoad;
      }
      statuses = await _core.getOverlayNetworkStatus(
        GetOverlayNetworkStatusParams(
          targets: [
            for (final proxy in targets)
              _target(proxy, OverlayNetworkDetailLevel.details),
          ],
        ),
      );
    } catch (value) {
      requestError = value;
    }
    if (!mounted) {
      return;
    }
    final shouldApply = isCurrent?.call() ?? true;
    final statusesByKey = {
      for (final status in statuses ?? const <OverlayNetworkStatus>[])
        _statusKey(status): status,
    };
    setState(() {
      for (final proxy in targets) {
        _loading.remove(_key(proxy));
      }
      if (!shouldApply) {
        return;
      }
      for (final proxy in targets) {
        final key = _key(proxy);
        if (requestError != null) {
          _requestErrors[key] = requestError;
          continue;
        }
        final status = statusesByKey[key];
        if (status == null) {
          _requestErrors[key] = 'Missing overlay network status';
          continue;
        }
        final previous = _statuses[key];
        _statuses[key] = previous == null
            ? status
            : status.retainDetailsFrom(previous);
        if (status.hasDetails) {
          _detailsLoaded.add(key);
        }
        _requestErrors.remove(key);
      }
    });
  }

  Future<void> _refreshStatuses() async {
    final proxies = _configuredProxies(ref.read(groupsProvider));
    await _loadSummaries(proxies, force: true);
    await _loadDetails([
      for (final proxy in proxies)
        if (_detailsLoaded.contains(_key(proxy))) proxy,
    ], force: true);
  }

  void _toggleAll(List<_NetworkingProxy> proxies) {
    final shouldExpand = proxies.every(
      (proxy) => !_expanded.contains(_key(proxy)),
    );
    setState(() {
      _expanded.clear();
      if (shouldExpand) {
        _expanded.addAll(proxies.map(_key));
      }
      _expansionGeneration++;
    });
    if (shouldExpand) {
      startPolling();
      unawaited(_loadDetails(proxies));
    } else {
      stopPolling();
    }
  }

  Future<void> _activateNetwork(_NetworkingProxy proxy) async {
    final key = _key(proxy);
    if (_activating.contains(key)) {
      return;
    }
    setState(() {
      _activating.add(key);
      _requestErrors.remove(key);
    });
    try {
      final status = await _core.activateOverlayNetwork(
        proxy.name,
        _kind(proxy),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final previous = _statuses[key];
        _statuses[key] = previous == null
            ? status
            : status.retainDetailsFrom(previous);
        _requestErrors.remove(key);
      });
      await _loadDetails([proxy], force: true);
    } catch (error) {
      if (mounted) {
        context.showSnackBar(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _activating.remove(key);
        });
      }
    }
  }

  Future<void> _logoutTailscale(String name) async {
    final proxy = (name: name, type: 'tailscale');
    final key = _key(proxy);
    if (_loggingOut.contains(key)) {
      return;
    }
    setState(() {
      _loggingOut.add(key);
    });
    try {
      await _core.logoutTailscale(name);
      await _loadDetails([proxy], force: true);
    } catch (error) {
      if (mounted) {
        context.showSnackBar(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut.remove(key);
        });
      }
    }
  }

  String _stateLabel(BuildContext context, OverlayNetworkStatus status) {
    final appLocalizations = context.appLocalizations;
    return switch (status.state) {
      OverlayNetworkState.uninitialized => appLocalizations.uninitialized,
      OverlayNetworkState.starting => appLocalizations.connecting,
      OverlayNetworkState.connected => appLocalizations.connected,
      OverlayNetworkState.needsLogin => appLocalizations.needsLogin,
      OverlayNetworkState.needsApproval =>
        appLocalizations.tailscaleNeedsMachineAuth,
      OverlayNetworkState.stopped => appLocalizations.stopped,
      OverlayNetworkState.error => switch (status.rawState) {
        'access-denied' => appLocalizations.accessDenied,
        'not-found' => appLocalizations.networkNotFound,
        _ => status.error.isNotEmpty ? status.error : appLocalizations.status,
      },
      OverlayNetworkState.unknown =>
        status.rawState.isNotEmpty ? status.rawState : appLocalizations.status,
    };
  }

  String _summary(BuildContext context, OverlayNetworkStatus status) {
    return [
      _stateLabel(context, status),
      if (status.networkName.isNotEmpty) status.networkName,
    ].join(' · ');
  }

  Widget? _statusErrorItem(
    BuildContext context,
    _NetworkingProxy proxy,
    OverlayNetworkStatus status,
  ) {
    if (status.error.isEmpty) {
      return null;
    }
    final key = _key(proxy);
    final label = _stateLabel(context, status);
    return ListItem(
      leading: Icon(Icons.error_outline, color: context.colorScheme.error),
      title: Text(label),
      subtitle: status.error == label ? null : Text(status.error),
      trailing: IconButton(
        tooltip: context.appLocalizations.sync,
        onPressed: _activating.contains(key)
            ? null
            : () => _activateNetwork(proxy),
        icon: _activating.contains(key)
            ? const SizedBox.square(dimension: 18, child: CommonCircleLoading())
            : const Icon(Icons.refresh),
      ),
    );
  }

  List<Widget> _proxyChildren(BuildContext context, _NetworkingProxy proxy) {
    final key = _key(proxy);
    if (_loading.contains(key) && !_detailsLoaded.contains(key)) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CommonCircleLoading()),
        ),
      ];
    }
    final error = _requestErrors[key];
    if (error != null) {
      return [
        ListItem(
          leading: Icon(Icons.error_outline, color: context.colorScheme.error),
          title: Text(error.toString()),
          trailing: IconButton(
            tooltip: context.appLocalizations.sync,
            onPressed: () => _loadDetails([proxy], force: true),
            icon: const Icon(Icons.refresh),
          ),
        ),
      ];
    }
    final status = _statuses[key];
    final statusErrorItem = status == null
        ? null
        : _statusErrorItem(context, proxy, status);
    final activationItem =
        status != null &&
            const {
              OverlayNetworkState.uninitialized,
              OverlayNetworkState.stopped,
            }.contains(status.state)
        ? ListItem(
            leading: const Icon(Icons.power_settings_new),
            title: Text(_stateLabel(context, status)),
            trailing: FilledButton.tonalIcon(
              onPressed: _activating.contains(key)
                  ? null
                  : () => _activateNetwork(proxy),
              icon: _activating.contains(key)
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CommonCircleLoading(),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(context.appLocalizations.initialize),
            ),
          )
        : null;
    if (status?.state == OverlayNetworkState.uninitialized &&
        activationItem != null) {
      return generateSection(isFirst: true, items: [activationItem]);
    }
    final tailscaleDetails = status?.tailscaleDetails;
    if (status != null && tailscaleDetails != null) {
      return [
        ...buildTailscaleChildren(
          context: context,
          controller: _core,
          status: status,
          details: tailscaleDetails,
          loggingOut: _loggingOut.contains(
            _key((name: status.name, type: 'tailscale')),
          ),
          onLogout: () => _logoutTailscale(status.name),
          statusErrorItem: statusErrorItem,
          activationItem: activationItem,
        ),
      ];
    }
    final zeroTierDetails = status?.zeroTierDetails;
    if (status != null && zeroTierDetails != null) {
      return [
        ...buildZeroTierChildren(
          context: context,
          status: status,
          details: zeroTierDetails,
          statusErrorItem: statusErrorItem,
          activationItem: activationItem,
        ),
      ];
    }
    return statusErrorItem == null && activationItem == null
        ? const []
        : generateSection(
            isFirst: true,
            items: [?statusErrorItem, ?activationItem],
          );
  }

  Widget _buildProxy(BuildContext context, _NetworkingProxy proxy) {
    final key = _key(proxy);
    final status = _statuses[key];
    final error = _requestErrors[key];
    final protocol = proxy.type == 'tailscale' ? 'Tailscale' : 'ZeroTier';
    final summary = status == null ? null : _summary(context, status);
    return Material(
      type: MaterialType.transparency,
      child: ExpansionTile(
        key: PageStorageKey('$key\u0000$_expansionGeneration'),
        initiallyExpanded: _expanded.contains(key),
        expansionAnimationStyle: const AnimationStyle(
          duration: animateDuration,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        onExpansionChanged: (expanded) {
          setState(() {
            if (expanded) {
              _expanded.add(key);
            } else {
              _expanded.remove(key);
            }
          });
          if (expanded) {
            startPolling();
            _loadDetails([proxy]);
          } else {
            if (_expanded.isEmpty) {
              stopPolling();
            }
          }
        },
        leading: error != null || status?.state == OverlayNetworkState.error
            ? Icon(Icons.error_outline, color: context.colorScheme.error)
            : SvgPicture.asset(
                'assets/images/networking/${proxy.type}.svg',
                key: ValueKey('networking-${proxy.type}-icon'),
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  context.colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
        title: Text(proxy.name, style: context.textTheme.bodyLarge?.toSoftBold),
        subtitle: Text([protocol, ?summary].join(' · ')),
        children: _proxyChildren(context, proxy),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<_NetworkingProxy> proxies) {
    if (proxies.isEmpty) {
      return NullStatus(label: context.appLocalizations.networkingNoOutbounds);
    }
    return RefreshIndicator(
      onRefresh: _refreshStatuses,
      child: generateListView([
        for (final proxy in proxies) _buildProxy(context, proxy),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final proxies = _configuredProxies(ref.watch(groupsProvider));
    if (_pageActive &&
        proxies.any(
          (proxy) =>
              !_summariesLoaded.contains(_key(proxy)) && _summaryLoad == null,
        )) {
      _scheduleSummaryRefresh();
    }
    final allCollapsed = proxies.every(
      (proxy) => !_expanded.contains(_key(proxy)),
    );
    return CommonScaffold(
      title: appLocalizations.networking,
      actions: [
        if (proxies.isNotEmpty)
          IconButton(
            tooltip: allCollapsed
                ? appLocalizations.expand
                : appLocalizations.collapse,
            onPressed: () => _toggleAll(proxies),
            icon: Icon(allCollapsed ? Icons.unfold_more : Icons.unfold_less),
          ),
        IconButton(
          tooltip: appLocalizations.sync,
          onPressed: proxies.isEmpty || _isLoading ? null : _refreshStatuses,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CommonCircleLoading(),
                )
              : const Icon(Icons.refresh),
        ),
      ],
      body: _buildBody(context, proxies),
    );
  }
}

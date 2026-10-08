part of '../action.dart';

@Riverpod(keepAlive: true)
class CommonAction extends _$CommonAction {
  CoreController get _core => ref.read(coreHandlerProvider);
  bool _isUpdatingTraffic = false;

  @override
  void build() {}

  void toggleRunning() {
    final running = !ref.read(isStartProvider);
    unawaited(
      globalState.safeRun(
        () => ref
            .read(setupActionProvider.notifier)
            .setRunning(
              running,
              initialize: running && !ref.read(initProvider),
            ),
      ),
    );
  }

  void updateSpeedStatistics() {
    ref
        .read(vpnSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            networkSpeedNotification: !state.networkSpeedNotification,
          ),
        );
  }

  void updateMode() {
    ref.read(patchClashConfigProvider.notifier).update((state) {
      final index = Mode.values.indexWhere((item) => item == state.mode);
      if (index == -1) return state;
      final nextIndex = index + 1 > Mode.values.length - 1 ? 0 : index + 1;
      return state.copyWith(mode: Mode.values[nextIndex]);
    });
  }

  Future<void> updateTraffic() async {
    if (_isUpdatingTraffic) {
      return;
    }
    _isUpdatingTraffic = true;
    try {
      final onlyStatisticsProxy = ref.read(
        appSettingProvider.select((state) => state.onlyStatisticsProxy),
      );
      final [traffic, totalTraffic] = await Future.wait([
        _readTraffic(() => _core.getTraffic(onlyStatisticsProxy)),
        _readTraffic(() => _core.getTotalTraffic(onlyStatisticsProxy)),
      ]);
      if (traffic != null) {
        ref.read(trafficsProvider.notifier).addTraffic(traffic);
      }
      if (totalTraffic != null) {
        ref.read(totalTrafficProvider.notifier).value = totalTraffic;
      }
    } finally {
      _isUpdatingTraffic = false;
    }
  }

  Future<Traffic?> _readTraffic(Future<Traffic> Function() request) async {
    try {
      return await request();
    } catch (error) {
      commonPrint.log(
        'updateTraffic error: $error',
        logLevel: coreFailureLogLevel(error),
      );
      return null;
    }
  }

  Future<bool> autoCheckUpdate() async {
    if (!ref.read(appSettingProvider).autoCheckUpdate) return false;
    try {
      final res = await request.checkForUpdate();
      await checkUpdateResultHandle(data: res);
      return res != null;
    } catch (error, stackTrace) {
      commonPrint.log(
        'autoCheckUpdate failed: $error\n$stackTrace',
        logLevel: LogLevel.warning,
      );
      return false;
    }
  }

  TextSpan _releaseSpan(BuildContext context, String tagName, String? body) {
    final textTheme = context.textTheme;
    final version = parseReleaseChangelog(body);
    return TextSpan(
      text: '$tagName \n',
      style: textTheme.headlineSmall,
      children: version == null
          ? [
              TextSpan(text: '\n', style: textTheme.bodyMedium),
              for (final submit in parseReleaseBody(body))
                TextSpan(text: '- $submit \n', style: textTheme.bodyMedium),
            ]
          : _changelogSpans(context, version),
    );
  }

  List<TextSpan> _changelogSpans(
    BuildContext context,
    ChangelogVersion version,
  ) {
    final textTheme = context.textTheme;
    return [
      for (final group in version.visibleGroups) ...[
        TextSpan(
          text:
              '\n${changelogGroupTitle(currentAppLocalizations, group.type)}\n',
          style: textTheme.labelLarge?.copyWith(
            color: group.type == ChangelogType.breaking
                ? context.colorScheme.error
                : context.colorScheme.primary,
          ),
        ),
        for (final entry in group.entries)
          TextSpan(text: '• ${entry.text}\n', style: textTheme.bodyMedium),
      ],
    ];
  }

  Future<void> checkUpdateResultHandle({
    ReleaseManifest? data,
    bool isUser = false,
  }) async {
    if (data != null) {
      final message = _releaseSpan(
        globalState.navigatorKey.currentContext!,
        data.tag,
        data.notes,
      );
      final plan = await _planAppUpdate(data);
      final updatesInApp = plan?.target.package.updatesInApp ?? false;
      final res = await dialogs.showMessage(
        title: currentAppLocalizations.discoverNewVersion,
        message: message,
        leadingAction: TextButton(
          onPressed: () => launchUrl(
            Uri.https('github.com', '/$repository/releases/tag/${data.tag}'),
            mode: LaunchMode.externalApplication,
          ),
          child: Text(currentAppLocalizations.openInGitHub),
        ),
        confirmText: updatesInApp
            ? currentAppLocalizations.updateNow
            : currentAppLocalizations.goDownload,
        cancelText: isUser ? null : currentAppLocalizations.noLongerRemind,
      );
      if (res == true) {
        if (plan == null || !updatesInApp) {
          unawaited(launchUrl(browserDownloadUri(plan)));
        } else {
          await globalState.safeRun(
            () => _applyAppUpdate(plan),
            title: currentAppLocalizations.checkUpdate,
            silence: false,
          );
        }
      } else if (!isUser && res == false) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(autoCheckUpdate: false));
      }
    } else if (isUser) {
      unawaited(
        dialogs.showMessage(
          title: currentAppLocalizations.checkUpdate,
          message: TextSpan(text: currentAppLocalizations.checkUpdateError),
        ),
      );
    }
  }

  @visibleForTesting
  Future<UpdateTarget> Function() detectAppUpdateTarget = detectUpdateTarget;

  Future<AppUpdatePlan?> _planAppUpdate(ReleaseManifest release) async {
    try {
      return planAppUpdate(release, await detectAppUpdateTarget());
    } catch (error) {
      commonPrint.log(
        'update target detection failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  Future<void> _applyAppUpdate(AppUpdatePlan plan) async {
    final file = await _downloadAppUpdate(plan);
    if (file == null) {
      return;
    }
    final package = plan.target.package;
    switch (package) {
      case UpdatePackage.windowsInstaller:
        await appInstaller.startWindowsInstaller(file);
        await _exitForUpdate();
      case UpdatePackage.macosDmg:
        await appInstaller.startMacosInstall(file);
        await _exitForUpdate();
      case UpdatePackage.linuxAppImage:
        await appInstaller.replaceAppImage(file);
        await appInstaller.startAppImageRelaunch();
        await _exitForUpdate();
      case UpdatePackage.androidApk:
        await _installApk(file);
      case UpdatePackage.linuxDeb ||
          UpdatePackage.linuxRpm ||
          UpdatePackage.linuxPacman:
        if (await appInstaller.installWithPackageManager(plan, file)) {
          await appInstaller.startRelaunch();
          await _exitForUpdate();
        }
      case UpdatePackage.windowsPortable ||
          UpdatePackage.linuxPortable ||
          UpdatePackage.unsupported:
        throw StateError('$package cannot be installed in place');
    }
  }

  Future<File?> _downloadAppUpdate(AppUpdatePlan plan) async {
    final outcome = await dialogs.showCommonDialog<ProgressOutcome<File>>(
      dismissible: false,
      child: UpdateProgressDialog<File>(
        expectedTotal: plan.asset.size,
        task: (onProgress, cancelToken) => appInstaller.download(
          plan,
          onReceiveProgress: onProgress,
          cancelToken: cancelToken,
        ),
      ),
    );
    if (outcome == null) {
      return null;
    }
    final error = outcome.error;
    if (error == null) {
      return outcome.value;
    }
    if (error is DioException && error.type == DioExceptionType.cancel) {
      return null;
    }
    Error.throwWithStackTrace(error, outcome.stackTrace!);
  }

  Future<void> _exitForUpdate() {
    return ref.read(systemActionProvider.notifier).handleExit();
  }

  Future<void> _installApk(File apk) async {
    final status = await appInstaller.installApk(apk);
    switch (status) {
      case ApkInstallStatus.started:
        return;
      case ApkInstallStatus.permissionDenied:
        throw MessageException(currentAppLocalizations.updateInstallPermission);
      case ApkInstallStatus.failed:
        throw MessageException(currentAppLocalizations.updateInstallFailed);
    }
  }
}

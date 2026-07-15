import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkDetection extends ConsumerStatefulWidget {
  const NetworkDetection({super.key});

  @override
  ConsumerState<NetworkDetection> createState() => _NetworkDetectionState();
}

class _NetworkDetectionState extends ConsumerState<NetworkDetection> {
  bool _isIpVisible = true;

  String _countryCodeToEmoji(String countryCode) {
    final String code = countryCode.toUpperCase();
    if (code.length != 2) {
      return countryCode;
    }
    final int firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  String _getIpText(String ip) {
    if (_isIpVisible) {
      return ip;
    }
    if (ip.contains('.')) {
      // IPv4
      final parts = ip.split('.');
      if (parts.length == 4) {
        return '${parts[0]}.***.***.***';
      }
    } else if (ip.contains(':')) {
      // IPv6
      final parts = ip.split(':');
      if (parts.length >= 2) {
        return '${parts[0]}:${parts[1]}:****:****:****:****:****:****';
      }
    }
    return '***.***.***.***';
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final networkDetection = ref.watch(networkDetectionProvider);
    final ipInfo = networkDetection.ipInfo;
    final isLoading = networkDetection.isLoading;
    final emojiTextStyle = context.textTheme.titleMedium?.toLight.copyWith(
      fontFamily: FontFamily.twEmoji.value,
    );
    final titleTextStyle = context.colorScheme.onSurfaceVariant;
    final descTextStyle = context.textTheme.titleSmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: isLoading != true
            ? () => ref.read(networkDetectionProvider.notifier).startCheck()
            : null,
        onLongPress: () => copyText(context, ipInfo?.ip),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              height: globalState.measure.titleMediumHeight + 16,
              padding: baseInfoEdgeInsets.copyWith(bottom: 0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  ipInfo != null
                      ? Text(
                          _countryCodeToEmoji(ipInfo.countryCode),
                          style: emojiTextStyle,
                        )
                      : Icon(Icons.network_check, color: titleTextStyle),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 1,
                    child: TooltipText(
                      text: Text(
                        appLocalizations.networkDetection,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: descTextStyle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  AspectRatio(
                    aspectRatio: 1,
                    child: ExcludeFocus(
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: ipInfo != null
                            ? () {
                                setState(() {
                                  _isIpVisible = !_isIpVisible;
                                });
                              }
                            : null,
                        icon: Icon(
                          size: 16.ap,
                          _isIpVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: baseInfoEdgeInsets.copyWith(top: 0),
              child: SizedBox(
                height: globalState.measure.bodyMediumHeight + 2,
                child: FadeThroughBox(
                  child: ipInfo != null
                      ? TooltipText(
                          text: Text(
                            _getIpText(ipInfo.ip),
                            style: context.textTheme.bodyMedium?.toLight
                                .adjustSize(1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : isLoading == false && ipInfo == null
                      ? Text(
                          appLocalizations.timeout,
                          style: context.textTheme.bodyMedium
                              ?.copyWith(color: Colors.red)
                              .adjustSize(1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Container(
                          padding: const EdgeInsets.all(2),
                          child: const AspectRatio(
                            aspectRatio: 1,
                            child: CommonCircleLoading(),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

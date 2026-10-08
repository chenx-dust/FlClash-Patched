import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:material_ui/material_ui.dart';

typedef DownloadProgress = ({int received, int total});

typedef ProgressTask<T> =
    Future<T> Function(ProgressCallback onProgress, CancelToken cancelToken);

/// A null route result means the dialog was dismissed, which cancels the task.
typedef ProgressOutcome<T> = ({
  T? value,
  Object? error,
  StackTrace? stackTrace,
});

/// Pops with the task's outcome, so a caller awaiting the route knows the
/// dialog is gone before it shows anything else.
class UpdateProgressDialog<T> extends StatefulWidget {
  final ProgressTask<T> task;
  final int expectedTotal;

  const UpdateProgressDialog({
    super.key,
    required this.task,
    this.expectedTotal = 0,
  });

  @override
  State<UpdateProgressDialog<T>> createState() =>
      _UpdateProgressDialogState<T>();
}

class _UpdateProgressDialogState<T> extends State<UpdateProgressDialog<T>> {
  late final _progress = ValueNotifier<DownloadProgress>((
    received: 0,
    total: widget.expectedTotal,
  ));
  final _cancelToken = CancelToken();

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    final outcome = await _outcome();
    if (mounted) {
      Navigator.of(context).pop(outcome);
    }
  }

  Future<ProgressOutcome<T>> _outcome() async {
    try {
      final value = await widget.task((received, total) {
        if (!mounted) {
          return;
        }
        _progress.value = (
          received: received,
          total: total > 0 ? total : widget.expectedTotal,
        );
      }, _cancelToken);
      final cancelError = _cancelToken.cancelError;
      if (cancelError != null) {
        throw cancelError;
      }
      return (value: value, error: null, stackTrace: null);
    } catch (error, stackTrace) {
      return (value: null, error: error, stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _cancelToken.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.updateDownloading,
      actions: [
        TextButton(
          onPressed: _cancelToken.cancel,
          child: Text(appLocalizations.cancel),
        ),
      ],
      child: ValueListenableBuilder<DownloadProgress>(
        valueListenable: _progress,
        builder: (context, progress, _) {
          final (:received, :total) = progress;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: total > 0 ? received / total : null,
              ),
              const SizedBox(height: 8),
              Text(
                total > 0
                    ? '${received.traffic.show} / ${total.traffic.show}'
                    : received.traffic.show,
                style: context.textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

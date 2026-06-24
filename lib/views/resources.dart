import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' hide context;

class ResourcesView extends StatelessWidget {
  const ResourcesView({super.key});

  @override
  Widget build(BuildContext context) {
    const geoResources = GeoResource.values;
    return CommonScaffold(
      title: context.appLocalizations.resources,
      body: ListView.separated(
        itemBuilder: (_, index) {
          final geoResource = geoResources[index];
          return _GeoResourceListItem(geoResource);
        },
        separatorBuilder: (BuildContext context, int index) {
          return const Divider(height: 0);
        },
        itemCount: geoResources.length,
      ),
    );
  }
}

class _GeoResourceListItem extends ConsumerStatefulWidget {
  final GeoResource type;

  const _GeoResourceListItem(this.type);

  @override
  ConsumerState<_GeoResourceListItem> createState() =>
      _GeoResourceListItemState();
}

class _GeoResourceListItemState extends ConsumerState<_GeoResourceListItem> {
  String get fileName {
    return switch (widget.type) {
      GeoResource.MMDB => MMDB,
      GeoResource.ASN => ASN,
      GeoResource.GEOIP => GEOIP,
      GeoResource.GEOSITE => GEOSITE,
    };
  }

  Future<void> _updateUrl(String url) async {
    final newUrl = await globalState.showCommonDialog<String>(
      child: UpdateGeoUrlFormDialog(
        title: widget.type.name,
        url: url,
        defaultValue: defaultGeoXUrl[widget.type],
      ),
    );
    if (newUrl != null && newUrl != url && mounted) {
      try {
        ref
            .read(geoResourceActionProvider.notifier)
            .updateGeoResourceUrl(widget.type, newUrl);
      } catch (e) {
        globalState.showMessage(
          title: widget.type.name,
          message: TextSpan(text: e.toString()),
        );
      }
    }
  }

  Future<FileInfo> _getGeoFileLastModified(String fileName) async {
    final homePath = await appPath.homeDirPath;
    final file = File(join(homePath, fileName));
    final lastModified = await file.lastModified();
    final size = await file.length();
    return FileInfo(size: size, lastModified: lastModified);
  }

  Future<void> _handleUpdateGeoDataItem() async {
    await globalState.safeRun<void>(() async {
      await ref
          .read(geoResourceActionProvider.notifier)
          .updateGeoResource(widget.type);
    }, silence: false);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final isUpdating = ref.watch(isUpdatingProvider(widget.type.updatingKey));
    final url = ref.watch(
      patchClashConfigProvider.select((state) => state.geoXUrl[widget.type]),
    );
    return ListItem(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(widget.type.name),
      subtitle: url == null
          ? const SizedBox()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                FutureBuilder<FileInfo>(
                  future: _getGeoFileLastModified(fileName),
                  builder: (_, snapshot) {
                    final height = globalState.measure.bodyMediumHeight;
                    return SizedBox(
                      height: height,
                      child: snapshot.data == null
                          ? SizedBox(width: height, height: height)
                          : Text(
                              snapshot.data!.getDesc(context),
                              style: context.textTheme.bodyMedium,
                            ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(url, style: context.textTheme.bodyMedium?.toLight),
                const SizedBox(height: 12),
                Wrap(
                  runSpacing: 6,
                  spacing: 12,
                  runAlignment: WrapAlignment.center,
                  children: [
                    CommonChip(
                      avatar: const Icon(Icons.edit),
                      label: appLocalizations.edit,
                      onPressed: () {
                        _updateUrl(url);
                      },
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          child: isUpdating
                              ? const SizedBox(
                                  height: 30,
                                  width: 30,
                                  child: Padding(
                                    padding: EdgeInsets.all(2),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : CommonChip(
                                  avatar: const Icon(Icons.sync),
                                  label: appLocalizations.sync,
                                  onPressed: () {
                                    _handleUpdateGeoDataItem();
                                  },
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
    );
  }
}

class UpdateGeoUrlFormDialog extends StatelessWidget {
  final String title;
  final String url;
  final String? defaultValue;

  const UpdateGeoUrlFormDialog({
    super.key,
    required this.title,
    required this.url,
    this.defaultValue,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return InputDialog(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      title: title,
      value: url,
      resetValue: defaultValue,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return appLocalizations.emptyTip('').trim();
        }
        if (!value.isUrl) {
          return appLocalizations.urlTip('').trim();
        }
        return null;
      },
    );
  }
}

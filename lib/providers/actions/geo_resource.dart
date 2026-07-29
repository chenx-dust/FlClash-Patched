part of '../action.dart';

@Riverpod(keepAlive: true)
class GeoResourceAction extends _$GeoResourceAction {
  @override
  void build() {}

  Future<void> updateAllGeoResources() async {
    await _applyProfileBeforeUpdate();
    await Future.wait(
      GeoResource.values.map(
        (geoResource) => coreController.updateGeoData(geoResource.name),
      ),
    );
  }

  Future<void> updateGeoResource(GeoResource geoResource) async {
    await _applyProfileBeforeUpdate();
    await coreController.updateGeoData(geoResource.name);
  }

  Future<void> _applyProfileBeforeUpdate() async {
    debouncer.cancel(FunctionTag.applyProfile);
    await ref.read(setupActionProvider.notifier).applyProfile(silence: true);
  }

  void updateGeoResourceUrl(GeoResource geoResource, String newUrl) {
    if (!newUrl.isUrl) {
      throw 'Invalid url';
    }
    ref.read(patchClashConfigProvider.notifier).update((state) {
      return state.copyWith(geoXUrl: {...state.geoXUrl, geoResource: newUrl});
    });
  }
}

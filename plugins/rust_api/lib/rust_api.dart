library;

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

import 'src/rust/frb_generated.dart';

export 'src/rust/api/helper.dart';
export 'src/rust/api/ipc.dart';
export 'src/rust/frb_generated.dart' show RustLib;

/// Initializes the bridge with the crate's stable library name.
///
/// The Windows code generator can fall back to `UNKNOWN` when Cargo metadata
/// discovery fails, which would otherwise make startup load `UNKNOWN.dll`.
Future<void> initRustApi() async {
  final generatedConfig = RustLib.instance.defaultExternalLibraryLoaderConfig;
  final externalLibrary = await loadExternalLibrary(
    ExternalLibraryLoaderConfig(
      stem: 'rust_api',
      ioDirectory: generatedConfig.ioDirectory,
      webPrefix: generatedConfig.webPrefix,
      wasmBindgenName: generatedConfig.wasmBindgenName,
    ),
  );
  await RustLib.init(externalLibrary: externalLibrary);
}

#ifndef FLUTTER_PLUGIN_WINDOW_EXT_PLUGIN_H_
#define FLUTTER_PLUGIN_WINDOW_EXT_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

#include <memory>
#include <optional>

namespace window_ext {

class WindowExtPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit WindowExtPlugin(flutter::PluginRegistrarWindows* registrar);
  ~WindowExtPlugin() override;

  // Disallow copy and assign.
  WindowExtPlugin(const WindowExtPlugin&) = delete;
  WindowExtPlugin& operator=(const WindowExtPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::optional<LRESULT> HandleWindowProc(
      HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

  static bool IsActivationMessage(UINT message, UINT activation_message);

 private:
  flutter::PluginRegistrarWindows* registrar_ = nullptr;
  int window_proc_id_ = -1;
  UINT activation_message_ = 0;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

}  // namespace window_ext

#endif  // FLUTTER_PLUGIN_WINDOW_EXT_PLUGIN_H_

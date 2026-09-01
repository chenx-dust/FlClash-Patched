#ifndef FLUTTER_PLUGIN_TRAY_PLUGIN_INTERNAL_H_
#define FLUTTER_PLUGIN_TRAY_PLUGIN_INTERNAL_H_

#include <windows.h>

#include <shellapi.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <string>
#include <unordered_map>

namespace tray {

class TrayWindow;

class TrayPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  TrayPlugin(
      flutter::PluginRegistrarWindows* registrar,
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel);

  ~TrayPlugin() override;

  TrayPlugin(const TrayPlugin&) = delete;
  TrayPlugin& operator=(const TrayPlugin&) = delete;

 private:
  struct MenuItemLocation {
    HMENU menu;
    UINT position;
    bool checkbox;
  };

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  bool Show(const flutter::EncodableMap& arguments);
  void Hide();
  bool OpenMenu(bool bring_app_to_front);
  bool UpdateMenuItem(const flutter::EncodableMap& arguments);
  bool ApplyIcon(bool add);
  void RebuildMenu(HMENU menu, const flutter::EncodableList& items);
  void SendEvent(const char* name, const flutter::EncodableValue& arguments);

  std::optional<LRESULT> HandleWindowProc(HWND window,
                                          UINT message,
                                          WPARAM wparam,
                                          LPARAM lparam);
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<TrayWindow> tray_window_;
  flutter::PluginRegistrarWindows* registrar_;

  NOTIFYICONDATAW icon_data_{};
  HMENU menu_ = nullptr;
  std::unordered_map<std::string, MenuItemLocation> menu_items_;
  std::wstring tool_tip_;
  bool visible_ = false;
  bool menu_is_dark_ = false;

  UINT taskbar_created_message_ = 0;
};

}  // namespace tray

#endif  // FLUTTER_PLUGIN_TRAY_PLUGIN_INTERNAL_H_

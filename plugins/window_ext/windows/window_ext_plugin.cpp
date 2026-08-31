#include "window_ext_plugin.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

#ifndef DWMWCP_DONOTROUND
#define DWMWCP_DONOTROUND 1
#endif

#ifndef DWMWCP_ROUND
#define DWMWCP_ROUND 2
#endif

namespace window_ext {

void WindowExtPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<WindowExtPlugin>(registrar);
  plugin->channel_->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

WindowExtPlugin::WindowExtPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar),
      activation_message_(
          ::RegisterWindowMessageW(L"FlClash.ActivateWindow")),
      channel_(std::make_unique<
               flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "window_ext",
          &flutter::StandardMethodCodec::GetInstance())) {
  window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
      [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
        return HandleWindowProc(hwnd, message, wparam, lparam);
      });
}

WindowExtPlugin::~WindowExtPlugin() {
  if (registrar_ != nullptr && window_proc_id_ != -1) {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  }
}

bool WindowExtPlugin::IsActivationMessage(UINT message,
                                          UINT activation_message) {
  return activation_message != 0 && message == activation_message;
}

std::optional<LRESULT> WindowExtPlugin::HandleWindowProc(
    HWND, UINT message, WPARAM, LPARAM) {
  if (IsActivationMessage(message, activation_message_)) {
    channel_->InvokeMethod(
        "windowActivated", std::make_unique<flutter::EncodableValue>());
  }
  return std::nullopt;
}

void WindowExtPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() != "setWindowCornerPreference") {
    result->NotImplemented();
    return;
  }

  const auto* arguments =
      std::get_if<flutter::EncodableMap>(method_call.arguments());
  if (arguments == nullptr) {
    result->Error("bad_args", "Expected an argument map");
    return;
  }
  const auto round_it = arguments->find(flutter::EncodableValue("round"));
  if (round_it == arguments->end() ||
      !std::holds_alternative<bool>(round_it->second)) {
    result->Error("bad_args", "round must be a bool");
    return;
  }

  const HWND window =
      ::GetAncestor(registrar_->GetView()->GetNativeWindow(), GA_ROOT);
  if (window == nullptr) {
    result->Error("unavailable", "Root window is unavailable");
    return;
  }
  const DWORD preference = std::get<bool>(round_it->second)
                               ? DWMWCP_ROUND
                               : DWMWCP_DONOTROUND;
  const HRESULT status = ::DwmSetWindowAttribute(
      window, DWMWA_WINDOW_CORNER_PREFERENCE, &preference,
      sizeof(preference));
  result->Success(flutter::EncodableValue(SUCCEEDED(status)));
}

}  // namespace window_ext

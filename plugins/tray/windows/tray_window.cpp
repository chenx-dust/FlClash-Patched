#include "tray_window.h"

#include <utility>

namespace tray {

namespace {

constexpr wchar_t kTrayWindowClassName[] = L"FlClash.TrayPlugin.HiddenWindow";

}

TrayWindow::TrayWindow(MessageHandler message_handler)
    : message_handler_(std::move(message_handler)) {}

TrayWindow::~TrayWindow() {
  message_handler_ = nullptr;
  if (hwnd_ != nullptr) {
    ::DestroyWindow(hwnd_);
    hwnd_ = nullptr;
  }
  if (owns_window_class_) {
    ::UnregisterClassW(kTrayWindowClassName, instance_);
  }
}

bool TrayWindow::Create() {
  instance_ = ::GetModuleHandleW(nullptr);

  WNDCLASSW window_class{};
  window_class.lpfnWndProc = WindowProc;
  window_class.hInstance = instance_;
  window_class.lpszClassName = kTrayWindowClassName;

  const ATOM window_class_atom = ::RegisterClassW(&window_class);
  if (window_class_atom == 0 && ::GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
    return false;
  }
  owns_window_class_ = window_class_atom != 0;

  hwnd_ = ::CreateWindowExW(WS_EX_TOOLWINDOW, kTrayWindowClassName, L"",
                            WS_POPUP, 0, 0, 0, 0, nullptr, nullptr, instance_,
                            this);
  return hwnd_ != nullptr;
}

HWND TrayWindow::hwnd() const {
  return hwnd_;
}

LRESULT CALLBACK TrayWindow::WindowProc(HWND hwnd,
                                        UINT message,
                                        WPARAM wparam,
                                        LPARAM lparam) {
  auto* tray_window = reinterpret_cast<TrayWindow*>(
      ::GetWindowLongPtrW(hwnd, GWLP_USERDATA));

  if (message == WM_NCCREATE) {
    const auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    tray_window = static_cast<TrayWindow*>(create->lpCreateParams);
    ::SetWindowLongPtrW(hwnd, GWLP_USERDATA,
                        reinterpret_cast<LONG_PTR>(tray_window));
  }

  std::optional<LRESULT> result;
  if (tray_window != nullptr && tray_window->message_handler_) {
    result = tray_window->message_handler_(hwnd, message, wparam, lparam);
  }

  if (message == WM_NCDESTROY && tray_window != nullptr) {
    ::SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
    tray_window->hwnd_ = nullptr;
  }

  if (result.has_value()) {
    return result.value();
  }
  return ::DefWindowProcW(hwnd, message, wparam, lparam);
}

}

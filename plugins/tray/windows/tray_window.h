#ifndef FLUTTER_PLUGIN_TRAY_WINDOW_H_
#define FLUTTER_PLUGIN_TRAY_WINDOW_H_

#include <windows.h>

#include <functional>
#include <optional>

namespace tray {

class TrayWindow {
 public:
  using MessageHandler =
      std::function<std::optional<LRESULT>(HWND, UINT, WPARAM, LPARAM)>;

  explicit TrayWindow(MessageHandler message_handler);
  ~TrayWindow();

  TrayWindow(const TrayWindow&) = delete;
  TrayWindow& operator=(const TrayWindow&) = delete;

  bool Create();
  HWND hwnd() const;

 private:
  static LRESULT CALLBACK WindowProc(HWND hwnd,
                                     UINT message,
                                     WPARAM wparam,
                                     LPARAM lparam);

  MessageHandler message_handler_;
  HINSTANCE instance_ = nullptr;
  HWND hwnd_ = nullptr;
  bool owns_window_class_ = false;
};

}

#endif

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <app_links/app_links_plugin_c_api.h>
#include <proxy/proxy_plugin_c_api.h>
#include <window_manager/window_manager_plugin.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

// The installer and the uninstaller run this before killing the app, which
// skips the exit path that normally turns the system proxy off.
constexpr char kClearStaleProxyArgument[] = "--clear-stale-proxy";
constexpr UINT kReleaseProxyTimeoutMilliseconds = 3000;

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  if (std::find(command_line_arguments.begin(), command_line_arguments.end(),
                kClearStaleProxyArgument) != command_line_arguments.end()) {
    // The uninstaller cannot run as the user who started it, so the running
    // app, which can, turns its proxy off. Its Core still holds the port, so
    // the stale check is left to the run after the kill.
    if (HWND running = WindowManagerFindRunningWindow()) {
      const UINT release_proxy =
          ::RegisterWindowMessageW(PROXY_PLUGIN_RELEASE_PROXY_MESSAGE);
      if (release_proxy != 0) {
        ::SendMessageTimeoutW(running, release_proxy, 0, 0, SMTO_ABORTIFHUNG,
                              kReleaseProxyTimeoutMilliseconds, nullptr);
      }
      return EXIT_SUCCESS;
    }
    return ProxyPluginClearStaleProxy() ? EXIT_SUCCESS : EXIT_FAILURE;
  }

  if (HWND running = WindowManagerFindRunningWindow()) {
    SendAppLink(running);
    WindowManagerActivateWindow(running);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"FlClash", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

#ifdef _DEBUG
constexpr const wchar_t kSingleInstanceMutexName[] =
    L"Local\\com.follow.clash.debug.SingleInstance";
#else
constexpr const wchar_t kSingleInstanceMutexName[] =
    L"Local\\com.follow.clash.SingleInstance";
#endif
constexpr const wchar_t kWindowClassName[] = L"FLCLASH_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kActivateWindowMessageName[] =
    L"FlClash.ActivateWindow";

HANDLE AcquireSingleInstanceMutex(bool* already_running) {
  *already_running = false;
  HANDLE mutex = ::CreateMutexW(nullptr, FALSE, kSingleInstanceMutexName);
  if (mutex == nullptr) {
    return nullptr;
  }
  if (::GetLastError() != ERROR_ALREADY_EXISTS) {
    return mutex;
  }

  *already_running = true;
  HWND existing_window = ::FindWindowW(kWindowClassName, nullptr);
  if (existing_window != nullptr) {
    DWORD process_id = 0;
    ::GetWindowThreadProcessId(existing_window, &process_id);
    if (process_id != 0) {
      ::AllowSetForegroundWindow(process_id);
    }
    const UINT activate_message =
        ::RegisterWindowMessageW(kActivateWindowMessageName);
    if (activate_message != 0) {
      ::PostMessageW(existing_window, activate_message, 0, 0);
    }
  }
  ::CloseHandle(mutex);
  return nullptr;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  bool already_running = false;
  HANDLE single_instance_mutex =
      AcquireSingleInstanceMutex(&already_running);
  if (single_instance_mutex == nullptr) {
    return already_running ? EXIT_SUCCESS : EXIT_FAILURE;
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

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"FlClash", origin, size)) {
    ::CloseHandle(single_instance_mutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  ::CloseHandle(single_instance_mutex);
  return EXIT_SUCCESS;
}

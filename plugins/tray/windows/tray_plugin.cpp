#include "tray_plugin.h"
#include "tray_window.h"

#include <strsafe.h>

#include <variant>

namespace tray {

namespace {

constexpr UINT kTrayCallbackMessage = WM_USER + 1;
constexpr UINT kTrayIconId = 1;

using SetPreferredAppModeFunc = int(WINAPI*)(int mode);
using AllowDarkModeForWindowFunc = BOOL(WINAPI*)(HWND hwnd, BOOL allow);
using FlushMenuThemesFunc = void(WINAPI*)();

enum PreferredAppMode {
  kDefaultAppMode = 0,
  kAllowDarkAppMode = 1,
};

SetPreferredAppModeFunc set_preferred_app_mode = nullptr;
AllowDarkModeForWindowFunc allow_dark_mode_for_window = nullptr;
FlushMenuThemesFunc flush_menu_themes = nullptr;
bool dark_mode_apis_initialized = false;
bool last_menu_is_dark = false;
bool has_menu_brightness = false;

void ApplyMenuBrightness(HWND window, bool is_dark) {
  if (!dark_mode_apis_initialized) {
    const HMODULE ux_theme = ::LoadLibraryW(L"uxtheme.dll");
    if (ux_theme != nullptr) {
      set_preferred_app_mode = reinterpret_cast<SetPreferredAppModeFunc>(
          ::GetProcAddress(ux_theme, MAKEINTRESOURCEA(135)));
      allow_dark_mode_for_window =
          reinterpret_cast<AllowDarkModeForWindowFunc>(
              ::GetProcAddress(ux_theme, MAKEINTRESOURCEA(133)));
      flush_menu_themes = reinterpret_cast<FlushMenuThemesFunc>(
          ::GetProcAddress(ux_theme, MAKEINTRESOURCEA(136)));
    }
    dark_mode_apis_initialized = true;
  }

  const bool changed = !has_menu_brightness || last_menu_is_dark != is_dark;
  if (changed && set_preferred_app_mode != nullptr) {
    set_preferred_app_mode(is_dark ? kAllowDarkAppMode : kDefaultAppMode);
  }
  if (allow_dark_mode_for_window != nullptr && window != nullptr) {
    allow_dark_mode_for_window(window, is_dark ? TRUE : FALSE);
  }
  if (changed && flush_menu_themes != nullptr) {
    flush_menu_themes();
  }

  last_menu_is_dark = is_dark;
  has_menu_brightness = true;
}

const flutter::EncodableValue* ValueAt(const flutter::EncodableMap& map,
                                       const char* key) {
  const auto it = map.find(flutter::EncodableValue(key));
  return it == map.end() ? nullptr : &(it->second);
}

const std::string* StringAt(const flutter::EncodableMap& map, const char* key) {
  return std::get_if<std::string>(ValueAt(map, key));
}

bool BoolAt(const flutter::EncodableMap& map, const char* key, bool fallback) {
  const auto* value = std::get_if<bool>(ValueAt(map, key));
  return value == nullptr ? fallback : *value;
}

const bool* BoolPointerAt(const flutter::EncodableMap& map, const char* key) {
  return std::get_if<bool>(ValueAt(map, key));
}

int IntAt(const flutter::EncodableMap& map, const char* key, int fallback) {
  const auto* value = std::get_if<int>(ValueAt(map, key));
  return value == nullptr ? fallback : *value;
}

const flutter::EncodableList* ListAt(const flutter::EncodableMap& map,
                                     const char* key) {
  return std::get_if<flutter::EncodableList>(ValueAt(map, key));
}

const flutter::EncodableMap* MapAt(const flutter::EncodableMap& map,
                                   const char* key) {
  return std::get_if<flutter::EncodableMap>(ValueAt(map, key));
}

std::wstring Utf16FromUtf8(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }
  const int size = ::MultiByteToWideChar(
      CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0);
  if (size <= 0) {
    return std::wstring();
  }
  std::wstring result(static_cast<size_t>(size), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, value.data(),
                        static_cast<int>(value.size()), result.data(), size);
  return result;
}

}  // namespace

// static
void TrayPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "tray",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<TrayPlugin>(registrar, std::move(channel));
  registrar->AddPlugin(std::move(plugin));
}

TrayPlugin::TrayPlugin(
    flutter::PluginRegistrarWindows* registrar,
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel)
    : channel_(std::move(channel)),
      tray_window_(std::make_unique<TrayWindow>(
          [this](HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
            return HandleWindowProc(window, message, wparam, lparam);
          })),
      registrar_(registrar) {
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });

  if (!tray_window_->Create()) {
    tray_window_.reset();
  }
  taskbar_created_message_ = ::RegisterWindowMessageW(L"TaskbarCreated");
}

TrayPlugin::~TrayPlugin() {
  Hide();
  tray_window_.reset();
}

void TrayPlugin::SendEvent(const char* name,
                           const flutter::EncodableValue& arguments) {
  channel_->InvokeMethod(name,
                         std::make_unique<flutter::EncodableValue>(arguments));
}

bool TrayPlugin::ApplyIcon(bool add) {
  if (tray_window_ == nullptr || tray_window_->hwnd() == nullptr) {
    return false;
  }
  icon_data_.cbSize = sizeof(NOTIFYICONDATAW);
  icon_data_.hWnd = tray_window_->hwnd();
  icon_data_.uID = kTrayIconId;
  icon_data_.uCallbackMessage = kTrayCallbackMessage;
  icon_data_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  ::StringCchCopyW(icon_data_.szTip, ARRAYSIZE(icon_data_.szTip),
                   tool_tip_.c_str());

  return ::Shell_NotifyIconW(add ? NIM_ADD : NIM_MODIFY, &icon_data_) != FALSE;
}

void TrayPlugin::RebuildMenu(HMENU menu, const flutter::EncodableList& items) {
  while (::GetMenuItemCount(menu) > 0) {
    ::DeleteMenu(menu, 0, MF_BYPOSITION);
  }

  for (const auto& value : items) {
    const auto* entry = std::get_if<flutter::EncodableMap>(&value);
    if (entry == nullptr) {
      continue;
    }
    const std::string* type = StringAt(*entry, "type");
    if (type == nullptr) {
      continue;
    }

    if (*type == "separator") {
      ::AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
      continue;
    }

    const std::string* label = StringAt(*entry, "label");
    const std::wstring text = Utf16FromUtf8(label == nullptr ? "" : *label);
    const UINT position = static_cast<UINT>(::GetMenuItemCount(menu));

    UINT flags = MF_STRING;
    if (!BoolAt(*entry, "enabled", true)) {
      flags |= MF_GRAYED;
    }

    UINT_PTR item_id =
        static_cast<UINT_PTR>(IntAt(*entry, "id", 0));

    if (*type == "checkbox") {
      flags |= BoolAt(*entry, "checked", false) ? MF_CHECKED : MF_UNCHECKED;
    } else if (*type == "submenu") {
      HMENU submenu = ::CreatePopupMenu();
      const flutter::EncodableList* children = ListAt(*entry, "items");
      if (children != nullptr) {
        RebuildMenu(submenu, *children);
      }
      flags |= MF_POPUP;
      item_id = reinterpret_cast<UINT_PTR>(submenu);
    }

    ::AppendMenuW(menu, flags, item_id, text.c_str());

    const std::string* key = StringAt(*entry, "key");
    if (key != nullptr) {
      menu_items_.try_emplace(
          *key, MenuItemLocation{menu, position, *type == "checkbox"});
    }
  }
}

bool TrayPlugin::Show(const flutter::EncodableMap& arguments) {
  const flutter::EncodableMap* icon = MapAt(arguments, "icon");
  const std::string* icon_path =
      icon == nullptr ? nullptr : StringAt(*icon, "path");
  if (icon_path == nullptr) {
    return false;
  }

  const HICON loaded = static_cast<HICON>(::LoadImageW(
      nullptr, Utf16FromUtf8(*icon_path).c_str(), IMAGE_ICON,
      ::GetSystemMetrics(SM_CXSMICON), ::GetSystemMetrics(SM_CYSMICON),
      LR_LOADFROMFILE));
  if (loaded == nullptr) {
    return false;
  }
  const HICON previous_icon = icon_data_.hIcon;
  const std::wstring previous_tool_tip = tool_tip_;
  const bool previous_menu_is_dark = menu_is_dark_;
  icon_data_.hIcon = loaded;

  const std::string* tool_tip = StringAt(arguments, "toolTip");
  if (tool_tip != nullptr) {
    tool_tip_ = Utf16FromUtf8(*tool_tip);
  }
  const std::string* brightness = StringAt(arguments, "brightness");
  menu_is_dark_ = brightness != nullptr && *brightness == "dark";

  bool applied = ApplyIcon(!visible_);
  if (!applied && visible_) {
    applied = ApplyIcon(true);
  }
  if (!applied) {
    icon_data_.hIcon = previous_icon;
    tool_tip_ = previous_tool_tip;
    menu_is_dark_ = previous_menu_is_dark;
    ::DestroyIcon(loaded);
    return false;
  }
  if (previous_icon != nullptr) {
    ::DestroyIcon(previous_icon);
  }
  visible_ = true;

  const flutter::EncodableList* items = ListAt(arguments, "menu");
  if (items != nullptr) {
    if (menu_ == nullptr) {
      menu_ = ::CreatePopupMenu();
    }
    menu_items_.clear();
    RebuildMenu(menu_, *items);
  }

  return true;
}

void TrayPlugin::Hide() {
  if (visible_) {
    ::Shell_NotifyIconW(NIM_DELETE, &icon_data_);
  }
  if (icon_data_.hIcon != nullptr) {
    ::DestroyIcon(icon_data_.hIcon);
  }
  icon_data_ = NOTIFYICONDATAW{};

  if (menu_ != nullptr) {
    ::DestroyMenu(menu_);
    menu_ = nullptr;
  }
  menu_items_.clear();

  tool_tip_.clear();
  visible_ = false;
}

bool TrayPlugin::OpenMenu(bool bring_app_to_front) {
  if (menu_ == nullptr || !visible_) {
    return false;
  }

  HWND window = nullptr;
  if (bring_app_to_front) {
    if (registrar_ != nullptr && registrar_->GetView() != nullptr) {
      window = ::GetAncestor(registrar_->GetView()->GetNativeWindow(), GA_ROOT);
    }
  } else if (tray_window_ != nullptr) {
    window = tray_window_->hwnd();
  }
  if (window == nullptr) {
    return false;
  }
  POINT cursor;
  ::GetCursorPos(&cursor);

  ApplyMenuBrightness(window, menu_is_dark_);
  ::SetForegroundWindow(window);
  const int command = ::TrackPopupMenu(
      menu_, TPM_BOTTOMALIGN | TPM_LEFTALIGN | TPM_RETURNCMD | TPM_RIGHTBUTTON,
      cursor.x, cursor.y, 0, window, nullptr);
  ::PostMessageW(window, WM_NULL, 0, 0);

  if (command != 0) {
    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("id")] = flutter::EncodableValue(command);
    SendEvent("onMenuItemSelected", flutter::EncodableValue(arguments));
  } else {
    ::Shell_NotifyIconW(NIM_SETFOCUS, &icon_data_);
  }
  return true;
}

bool TrayPlugin::UpdateMenuItem(
    const flutter::EncodableMap& arguments) {
  const std::string* key = StringAt(arguments, "key");
  if (key == nullptr) {
    return false;
  }
  const auto location = menu_items_.find(*key);
  if (location == menu_items_.end()) {
    return false;
  }

  const std::string* label = StringAt(arguments, "label");
  const bool* enabled = BoolPointerAt(arguments, "enabled");
  const bool* checked = BoolPointerAt(arguments, "checked");
  if (label == nullptr && enabled == nullptr &&
      (checked == nullptr || !location->second.checkbox)) {
    return true;
  }

  MENUITEMINFOW info{};
  info.cbSize = sizeof(info);
  if (enabled != nullptr || (checked != nullptr && location->second.checkbox)) {
    info.fMask = MIIM_STATE;
    if (!::GetMenuItemInfoW(location->second.menu, location->second.position,
                            TRUE, &info)) {
      return false;
    }
    if (enabled != nullptr) {
      info.fState &= ~(MFS_DISABLED | MFS_GRAYED);
      if (!*enabled) {
        info.fState |= MFS_DISABLED;
      }
    }
    if (checked != nullptr && location->second.checkbox) {
      info.fState &= ~MFS_CHECKED;
      if (*checked) {
        info.fState |= MFS_CHECKED;
      }
    }
  }

  std::wstring text;
  if (label != nullptr) {
    text = Utf16FromUtf8(*label);
    info.fMask |= MIIM_STRING;
    info.dwTypeData = text.data();
  }
  return ::SetMenuItemInfoW(location->second.menu, location->second.position,
                            TRUE, &info) != FALSE;
}

std::optional<LRESULT> TrayPlugin::HandleWindowProc(HWND window,
                                                    UINT message,
                                                    WPARAM wparam,
                                                    LPARAM lparam) {
  if (message == WM_DESTROY) {
    Hide();
    return std::nullopt;
  }

  if (message == kTrayCallbackMessage) {
    if (lparam == WM_LBUTTONUP) {
      SendEvent("onIconActivated", flutter::EncodableValue());
    } else if (lparam == WM_RBUTTONUP) {
      SendEvent("onMenuRequested", flutter::EncodableValue());
    }
    return std::nullopt;
  }

  const bool should_restore =
      (taskbar_created_message_ != 0 && message == taskbar_created_message_) ||
      (message == WM_POWERBROADCAST && (wparam == PBT_APMRESUMEAUTOMATIC ||
                                        wparam == PBT_APMRESUMESUSPEND));
  if (should_restore && visible_) {
    ApplyIcon(true);
  }

  return std::nullopt;
}

void TrayPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "show") {
    const auto* arguments =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    result->Success(flutter::EncodableValue(
        arguments != nullptr && Show(*arguments)));
    return;
  }

  if (method == "hide") {
    Hide();
    result->Success(flutter::EncodableValue(true));
    return;
  }

  if (method == "openMenu") {
    const auto* arguments =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    const bool bring_app_to_front =
        arguments != nullptr && BoolAt(*arguments, "bringAppToFront", false);
    result->Success(flutter::EncodableValue(
        OpenMenu(bring_app_to_front)));
    return;
  }

  if (method == "updateMenuItem") {
    const auto* arguments =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    result->Success(flutter::EncodableValue(
        arguments != nullptr && UpdateMenuItem(*arguments)));
    return;
  }

  if (method == "setTitle") {
    result->Success(flutter::EncodableValue(false));
    return;
  }

  result->NotImplemented();
}

}  // namespace tray

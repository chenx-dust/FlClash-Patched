#include "tray_plugin.h"
#include "tray_menu_session.h"
#include "tray_window.h"

#include <strsafe.h>

#include <variant>

namespace tray {

namespace {

constexpr UINT kTrayCallbackMessage = WM_USER + 1;
constexpr UINT kTrayIconId = 1;
constexpr UINT_PTR kRestoreTimerId = 0x54524159;  // "TRAY"
constexpr UINT kRestoreIntervalMilliseconds = 2000;
constexpr int kMaxRestoreAttempts = 30;

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

std::wstring MenuText(const std::string& label, const std::string& sublabel) {
  std::string text = label;
  if (!sublabel.empty()) {
    text += "\t" + sublabel;
  }
  size_t position = 0;
  while ((position = text.find('&', position)) != std::string::npos) {
    text.insert(position, 1, '&');
    position += 2;
  }
  return Utf16FromUtf8(text);
}

void UpdateMenuEntry(flutter::EncodableMap& entry,
                     const flutter::EncodableMap& update) {
  for (const char* key : {"label", "sublabel", "sublabelStyle"}) {
    if (const auto* value = StringAt(update, key)) {
      entry[flutter::EncodableValue(key)] = flutter::EncodableValue(*value);
    }
  }
  for (const char* key : {"enabled", "checked"}) {
    if (const auto* value = BoolPointerAt(update, key)) {
      entry[flutter::EncodableValue(key)] = flutter::EncodableValue(*value);
    }
  }
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

void TrayPlugin::IndexMenuItems(flutter::EncodableList& items) {
  for (auto& value : items) {
    auto* entry = std::get_if<flutter::EncodableMap>(&value);
    if (entry == nullptr) {
      continue;
    }
    if (const auto* key = StringAt(*entry, "key")) {
      menu_entries_.try_emplace(*key, entry);
    }
    const auto children = entry->find(flutter::EncodableValue("items"));
    if (children != entry->end()) {
      if (auto* list = std::get_if<flutter::EncodableList>(&children->second)) {
        IndexMenuItems(*list);
      }
    }
  }
}

void TrayPlugin::MaterializeMenu(HMENU menu) {
  open_menus_.insert(menu);
  const auto deferred = deferred_menus_.find(menu);
  if (deferred == deferred_menus_.end()) {
    for (const auto& [key, location] : menu_items_) {
      if (location.menu == menu) {
        ApplyMenuItemUpdate(*menu_entries_.at(key));
      }
    }
    return;
  }
  const auto* items = deferred->second;
  deferred_menus_.erase(deferred);
  RebuildMenu(menu, *items);
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
    const std::string* sublabel = StringAt(*entry, "sublabel");
    const std::string label_text = label == nullptr ? "" : *label;
    const std::string sublabel_text = sublabel == nullptr ? "" : *sublabel;
    const std::wstring text = MenuText(label_text, sublabel_text);
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
        deferred_menus_.emplace(submenu, children);
      }
      flags |= MF_POPUP;
      item_id = reinterpret_cast<UINT_PTR>(submenu);
    }

    if ((*type == "action" || *type == "checkbox") &&
        BoolAt(*entry, "keepsMenuOpen", false)) {
      persistent_menu_items_.insert(static_cast<UINT>(item_id));
    }
    ::AppendMenuW(menu, flags, item_id, text.c_str());

    const auto* style = StringAt(*entry, "sublabelStyle");
    const std::string sublabel_style = style == nullptr ? "badge" : *style;
    if (*type == "checkbox" && !sublabel_text.empty() &&
        (flags & MF_CHECKED) == 0) {
      MENUITEMINFOW info{};
      info.cbSize = sizeof(info);
      info.fMask = MIIM_BITMAP;
      info.hbmpItem = menu_icons_.Get(sublabel_style);
      ::SetMenuItemInfoW(menu, position, TRUE, &info);
    }

    const std::string* key = StringAt(*entry, "key");
    if (key != nullptr) {
      menu_items_.try_emplace(
          *key, MenuItemLocation{menu, position, *type == "checkbox",
                                 label_text, sublabel_text, sublabel_style});
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

  icon_requested_ = true;
  bool applied = ApplyIcon(!visible_);
  if (!applied && visible_) {
    applied = ApplyIcon(true);
  }
  // The shell refuses the first add while it is still starting at sign-in.
  const bool can_retry = !visible_ && tray_window_ != nullptr &&
                         tray_window_->hwnd() != nullptr;
  if (!applied && !can_retry) {
    icon_data_.hIcon = previous_icon;
    tool_tip_ = previous_tool_tip;
    menu_is_dark_ = previous_menu_is_dark;
    icon_requested_ = visible_;
    ::DestroyIcon(loaded);
    return false;
  }
  if (previous_icon != nullptr) {
    ::DestroyIcon(previous_icon);
  }
  if (applied) {
    visible_ = true;
  } else {
    restore_attempts_ = 0;
    ScheduleRestore();
  }

  const flutter::EncodableList* items = ListAt(arguments, "menu");
  if (items != nullptr) {
    SetMenu(*items);
  }

  return true;
}

void TrayPlugin::SetMenu(const flutter::EncodableList& items) {
  menu_icons_.SetAppearance(menu_dpi_, menu_is_dark_);
  if (menu_ == nullptr) {
    menu_ = ::CreatePopupMenu();
  }
  persistent_menu_items_.clear();
  open_menus_.clear();
  deferred_menus_.clear();
  menu_entries_.clear();
  menu_model_ = items;
  IndexMenuItems(menu_model_);
  menu_items_.clear();
  RebuildMenu(menu_, menu_model_);
}

void TrayPlugin::ScheduleRestore() {
  if (tray_window_ != nullptr && tray_window_->hwnd() != nullptr) {
    ::SetTimer(tray_window_->hwnd(), kRestoreTimerId,
               kRestoreIntervalMilliseconds, nullptr);
  }
}

void TrayPlugin::CancelRestore() {
  if (tray_window_ != nullptr && tray_window_->hwnd() != nullptr) {
    ::KillTimer(tray_window_->hwnd(), kRestoreTimerId);
  }
  restore_attempts_ = 0;
}

// An add that timed out may still have landed, so modify goes first. A shell
// that keeps refusing gets another round only when it announces a restart.
void TrayPlugin::RestoreIcon() {
  if (ApplyIcon(false) || ApplyIcon(true)) {
    visible_ = true;
    CancelRestore();
  } else if (++restore_attempts_ < kMaxRestoreAttempts) {
    ScheduleRestore();
  } else {
    CancelRestore();
  }
}

void TrayPlugin::Hide() {
  CancelRestore();
  if (icon_requested_) {
    ::Shell_NotifyIconW(NIM_DELETE, &icon_data_);
  }
  icon_requested_ = false;
  if (icon_data_.hIcon != nullptr) {
    ::DestroyIcon(icon_data_.hIcon);
  }
  icon_data_ = NOTIFYICONDATAW{};

  if (menu_ != nullptr) {
    ::DestroyMenu(menu_);
    menu_ = nullptr;
  }
  menu_items_.clear();
  deferred_menus_.clear();
  open_menus_.clear();
  menu_entries_.clear();
  menu_model_.clear();
  persistent_menu_items_.clear();
  menu_icons_.Clear();

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
  if (tray_window_ != nullptr && window == tray_window_->hwnd()) {
    ::SetWindowPos(window, nullptr, cursor.x, cursor.y, 0, 0,
                   SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
  }
  menu_dpi_ = ::GetDpiForWindow(window);
  if (menu_icons_.SetAppearance(menu_dpi_, menu_is_dark_)) {
    RefreshMenuIcons();
  }

  ApplyMenuBrightness(window, menu_is_dark_);
  ::SetForegroundWindow(window);
  TrayMenuSession session(window, persistent_menu_items_,
                           [this](int command) { SendMenuSelection(command); },
                           [this](HMENU menu) { MaterializeMenu(menu); },
                           [this](HMENU menu) { open_menus_.erase(menu); });
  const int command = ::TrackPopupMenu(
      menu_, TPM_BOTTOMALIGN | TPM_LEFTALIGN | TPM_RETURNCMD | TPM_RIGHTBUTTON,
      cursor.x, cursor.y, 0, window, nullptr);
  open_menus_.clear();
  ::PostMessageW(window, WM_NULL, 0, 0);

  if (command != 0) {
    SendMenuSelection(command);
  } else {
    ::Shell_NotifyIconW(NIM_SETFOCUS, &icon_data_);
  }
  return true;
}

void TrayPlugin::SendMenuSelection(int command) {
  flutter::EncodableMap arguments;
  arguments[flutter::EncodableValue("id")] = flutter::EncodableValue(command);
  const LONG timestamp = ::GetMessageTime();
  if (timestamp >= 0) {
    arguments[flutter::EncodableValue("activationTimestamp")] =
        flutter::EncodableValue(static_cast<int>(timestamp));
  }
  SendEvent("onMenuItemSelected", flutter::EncodableValue(arguments));
}

bool TrayPlugin::ApplyMenuItemUpdate(
    const flutter::EncodableMap& arguments) {
  const std::string* key = StringAt(arguments, "key");
  if (key == nullptr) {
    return false;
  }
  const auto entry = menu_entries_.find(*key);
  if (entry == menu_entries_.end()) {
    return false;
  }
  const auto location = menu_items_.find(*key);
  if (location == menu_items_.end() ||
      open_menus_.count(location->second.menu) == 0) {
    UpdateMenuEntry(*entry->second, arguments);
    return true;
  }

  const std::string* label = StringAt(arguments, "label");
  const std::string* sublabel = StringAt(arguments, "sublabel");
  const std::string* style = StringAt(arguments, "sublabelStyle");
  const bool* enabled = BoolPointerAt(arguments, "enabled");
  const bool* checked = BoolPointerAt(arguments, "checked");
  if (label == nullptr && sublabel == nullptr && style == nullptr && enabled == nullptr &&
      (checked == nullptr || !location->second.checkbox)) {
    return true;
  }

  MENUITEMINFOW info{};
  info.cbSize = sizeof(info);
  if (enabled != nullptr || location->second.checkbox) {
    info.fMask = MIIM_STATE | MIIM_BITMAP;
    if (!::GetMenuItemInfoW(location->second.menu, location->second.position,
                            TRUE, &info)) {
      return false;
    }
    const UINT previous_state = info.fState;
    info.fMask = 0;
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
    if (info.fState != previous_state) {
      info.fMask |= MIIM_STATE;
    }
  }

  const auto& next_label = label == nullptr ? location->second.label : *label;
  const auto& next_sublabel =
      sublabel == nullptr ? location->second.sublabel : *sublabel;
  const auto& next_style =
      style == nullptr ? location->second.sublabel_style : *style;
  std::wstring text;
  if (next_label != location->second.label ||
      next_sublabel != location->second.sublabel) {
    text = MenuText(next_label, next_sublabel);
    info.fMask |= MIIM_STRING;
    info.dwTypeData = text.data();
  }
  if (location->second.checkbox) {
    const HBITMAP bitmap =
        next_sublabel.empty() || (info.fState & MFS_CHECKED) != 0
            ? nullptr
            : menu_icons_.Get(next_style);
    if (info.hbmpItem != bitmap) {
      info.fMask |= MIIM_BITMAP;
      info.hbmpItem = bitmap;
    }
  }
  if (info.fMask != 0 &&
      !::SetMenuItemInfoW(location->second.menu, location->second.position,
                          TRUE, &info)) {
    return false;
  }
  if (label != nullptr) {
    location->second.label = *label;
  }
  if (sublabel != nullptr) {
    location->second.sublabel = *sublabel;
  }
  if (style != nullptr) {
    location->second.sublabel_style = *style;
  }
  if (info.fMask != 0) {
    TrayMenuSession::InvalidateItem(location->second.menu,
                                    location->second.position);
  }
  UpdateMenuEntry(*entry->second, arguments);
  return true;
}

bool TrayPlugin::UpdateMenuItems(
    const flutter::EncodableList& updates) {
  for (const auto& value : updates) {
    const auto* update = std::get_if<flutter::EncodableMap>(&value);
    if (update == nullptr) {
      return false;
    }
    const std::string* key = StringAt(*update, "key");
    if (key == nullptr || menu_entries_.find(*key) == menu_entries_.end()) {
      return false;
    }
  }
  for (const auto& value : updates) {
    const auto& update = std::get<flutter::EncodableMap>(value);
    if (!ApplyMenuItemUpdate(update)) {
      return false;
    }
  }
  return true;
}

void TrayPlugin::RefreshMenuIcons() {
  for (const auto& entry : menu_items_) {
    const auto& item = entry.second;
    if (item.checkbox) {
      MENUITEMINFOW info{};
      info.cbSize = sizeof(info);
      info.fMask = MIIM_STATE;
      if (!::GetMenuItemInfoW(item.menu, item.position, TRUE, &info)) {
        continue;
      }
      info.fMask = MIIM_BITMAP;
      info.hbmpItem = item.sublabel.empty() || (info.fState & MFS_CHECKED) != 0
                          ? nullptr
                          : menu_icons_.Get(item.sublabel_style);
      ::SetMenuItemInfoW(item.menu, item.position, TRUE, &info);
    }
  }
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

  if (message == WM_TIMER && wparam == kRestoreTimerId) {
    RestoreIcon();
    return 0;
  }

  const bool should_restore =
      (taskbar_created_message_ != 0 && message == taskbar_created_message_) ||
      (message == WM_POWERBROADCAST && (wparam == PBT_APMRESUMEAUTOMATIC ||
                                        wparam == PBT_APMRESUMESUSPEND));
  if (should_restore && icon_requested_) {
    CancelRestore();
    RestoreIcon();
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

  if (method == "updateMenuItems") {
    const auto* arguments =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    const auto* updates =
        arguments == nullptr ? nullptr : ListAt(*arguments, "updates");
    result->Success(flutter::EncodableValue(
        updates != nullptr && UpdateMenuItems(*updates)));
    return;
  }

  if (method == "setTitle") {
    result->Success(flutter::EncodableValue(false));
    return;
  }

  result->NotImplemented();
}

}  // namespace tray

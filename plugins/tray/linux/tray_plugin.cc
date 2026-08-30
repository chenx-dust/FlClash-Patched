#include "include/tray/tray_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#ifdef HAVE_AYATANA
#include <libayatana-appindicator/app-indicator.h>
#else
#include <libappindicator/app-indicator.h>
#endif

#include <cstring>

#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif

#define TRAY_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), tray_plugin_get_type(), TrayPlugin))

struct _TrayPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
  FlMethodChannel* channel;
  AppIndicator* indicator;
  GtkWidget* menu;
  GDBusConnection* session_bus;
  guint session_bus_filter_id;
  gchar* pending_activation_token;
};

G_DEFINE_TYPE(TrayPlugin, tray_plugin, g_object_get_type())

static TrayPlugin* active_plugin = nullptr;

struct MenuActivation {
  int id;
  bool activates_window;
};

static FlMethodResponse* respond(bool value) {
  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(value)));
}

static const char* string_value(FlValue* map, const char* key) {
  if (map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  FlValue* value = fl_value_lookup_string(map, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return nullptr;
  }
  return fl_value_get_string(value);
}

static bool bool_value(FlValue* map, const char* key, bool fallback) {
  FlValue* value = fl_value_lookup_string(map, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_BOOL) {
    return fallback;
  }
  return fl_value_get_bool(value);
}

static bool bool_value_if_present(FlValue* map,
                                  const char* key,
                                  bool* result) {
  if (map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) {
    return false;
  }
  FlValue* value = fl_value_lookup_string(map, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_BOOL) {
    return false;
  }
  *result = fl_value_get_bool(value);
  return true;
}

static GtkWindow* get_window(TrayPlugin* self) {
  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr) {
    return nullptr;
  }
  return GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static guint32 get_activation_timestamp(TrayPlugin* self) {
  guint32 timestamp = gtk_get_current_event_time();
#ifdef GDK_WINDOWING_X11
  if (timestamp == GDK_CURRENT_TIME) {
    GtkWindow* window = get_window(self);
    GdkWindow* gdk_window =
        window == nullptr ? nullptr : gtk_widget_get_window(GTK_WIDGET(window));
    if (gdk_window != nullptr && GDK_IS_X11_WINDOW(gdk_window)) {
      timestamp = gdk_x11_get_server_time(gdk_window);
    }
  }
#endif
  return timestamp;
}

static void activate_window(TrayPlugin* self) {
  GtkWindow* window = get_window(self);
  if (window == nullptr) {
    return;
  }

#ifdef GDK_WINDOWING_WAYLAND
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  if (self->pending_activation_token != nullptr &&
      GDK_IS_WAYLAND_DISPLAY(display)) {
    gdk_wayland_display_set_startup_notification_id(
        display, self->pending_activation_token);
    g_clear_pointer(&self->pending_activation_token, g_free);
    gtk_window_present(window);
    return;
  }
#endif

  const guint32 timestamp = get_activation_timestamp(self);
  if (timestamp == GDK_CURRENT_TIME) {
    gtk_window_present(window);
  } else {
    gtk_window_present_with_time(window, timestamp);
  }
}

static gboolean set_pending_activation_token(gpointer data) {
  if (active_plugin != nullptr) {
    const gchar* token = static_cast<const gchar*>(data);
    g_free(active_plugin->pending_activation_token);
    active_plugin->pending_activation_token =
        *token == '\0' ? nullptr : g_strdup(token);
  }
  return G_SOURCE_REMOVE;
}

static GDBusMessage* session_bus_filter(GDBusConnection* connection,
                                        GDBusMessage* message,
                                        gboolean incoming,
                                        gpointer) {
  if (!incoming ||
      g_dbus_message_get_message_type(message) !=
          G_DBUS_MESSAGE_TYPE_METHOD_CALL ||
      g_strcmp0(g_dbus_message_get_interface(message),
                "org.kde.StatusNotifierItem") != 0 ||
      g_strcmp0(g_dbus_message_get_member(message),
                "ProvideXdgActivationToken") != 0) {
    return message;
  }

  GVariant* body = g_dbus_message_get_body(message);
  if (body == nullptr || !g_variant_is_of_type(body, G_VARIANT_TYPE("(s)"))) {
    return message;
  }

  const gchar* token = nullptr;
  g_variant_get(body, "(&s)", &token);
  g_main_context_invoke_full(nullptr, G_PRIORITY_DEFAULT,
                             set_pending_activation_token, g_strdup(token),
                             g_free);

  g_autoptr(GDBusMessage) reply = g_dbus_message_new_method_reply(message);
  g_dbus_connection_send_message(connection, reply,
                                 G_DBUS_SEND_MESSAGE_FLAGS_NONE, nullptr,
                                 nullptr);
  g_object_unref(message);
  return nullptr;
}

static void free_menu_activation(gpointer data, GClosure*) {
  g_free(data);
}

static void on_menu_item_activate(GtkMenuItem*, gpointer user_data) {
  if (active_plugin == nullptr) {
    return;
  }
  const auto* activation = static_cast<MenuActivation*>(user_data);
  if (activation->activates_window) {
    activate_window(active_plugin);
  }
  g_autoptr(FlValue) arguments = fl_value_new_map();
  fl_value_set_string_take(arguments, "id", fl_value_new_int(activation->id));
  fl_method_channel_invoke_method(active_plugin->channel, "onMenuItemSelected",
                                  arguments, nullptr, nullptr, nullptr);
}

static GtkWidget* build_menu(FlValue* items) {
  GtkWidget* menu = gtk_menu_new();
  if (items == nullptr || fl_value_get_type(items) != FL_VALUE_TYPE_LIST) {
    return menu;
  }

  for (size_t i = 0; i < fl_value_get_length(items); i++) {
    FlValue* entry = fl_value_get_list_value(items, i);
    if (fl_value_get_type(entry) != FL_VALUE_TYPE_MAP) {
      continue;
    }

    const char* type = string_value(entry, "type");
    if (type == nullptr) {
      continue;
    }

    if (strcmp(type, "separator") == 0) {
      gtk_menu_shell_append(GTK_MENU_SHELL(menu),
                            gtk_separator_menu_item_new());
      continue;
    }

    const char* label = string_value(entry, "label");
    if (label == nullptr) {
      label = "";
    }

    GtkWidget* item;
    bool dispatches = true;
    if (strcmp(type, "checkbox") == 0) {
      item = gtk_check_menu_item_new_with_label(label);
      gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(item),
                                     bool_value(entry, "checked", false));
    } else if (strcmp(type, "submenu") == 0) {
      item = gtk_menu_item_new_with_label(label);
      gtk_menu_item_set_submenu(GTK_MENU_ITEM(item),
                                build_menu(fl_value_lookup_string(entry,
                                                                  "items")));
      dispatches = false;
    } else {
      item = gtk_menu_item_new_with_label(label);
    }

    if (!bool_value(entry, "enabled", true)) {
      gtk_widget_set_sensitive(item, FALSE);
    }

    if (dispatches) {
      FlValue* id = fl_value_lookup_string(entry, "id");
      if (id != nullptr && fl_value_get_type(id) == FL_VALUE_TYPE_INT) {
        auto* activation = g_new0(MenuActivation, 1);
        activation->id = static_cast<int>(fl_value_get_int(id));
        activation->activates_window =
            bool_value(entry, "activatesWindow", false);
        g_signal_connect_data(G_OBJECT(item), "activate",
                              G_CALLBACK(on_menu_item_activate), activation,
                              free_menu_activation, G_CONNECT_DEFAULT);
      }
    }

    const char* key = string_value(entry, "key");
    if (key != nullptr) {
      g_object_set_data_full(G_OBJECT(item), "tray-menu-key", g_strdup(key),
                             g_free);
    }

    gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
  }
  return menu;
}

static GtkWidget* find_menu_item(GtkWidget* menu, const char* key) {
  GList* children = gtk_container_get_children(GTK_CONTAINER(menu));
  for (GList* current = children; current != nullptr; current = current->next) {
    GtkWidget* item = GTK_WIDGET(current->data);
    const char* item_key =
        static_cast<const char*>(g_object_get_data(G_OBJECT(item),
                                                   "tray-menu-key"));
    if (g_strcmp0(item_key, key) == 0) {
      g_list_free(children);
      return item;
    }
    GtkWidget* submenu = gtk_menu_item_get_submenu(GTK_MENU_ITEM(item));
    if (submenu != nullptr) {
      GtkWidget* match = find_menu_item(submenu, key);
      if (match != nullptr) {
        g_list_free(children);
        return match;
      }
    }
  }
  g_list_free(children);
  return nullptr;
}

static void attach_menu(TrayPlugin* self, FlValue* items) {
  GtkWidget* previous = self->menu;

  GtkWidget* menu = build_menu(items);
  g_object_ref_sink(menu);
  self->menu = menu;

  app_indicator_set_menu(self->indicator, GTK_MENU(menu));
  gtk_widget_show_all(menu);

  if (previous != nullptr) {
    gtk_widget_destroy(previous);
    g_object_unref(previous);
  }
}

static void apply_title(TrayPlugin* self, const char* title) {
  if (title == nullptr || title[0] == '\0') {
    app_indicator_set_label(self->indicator, nullptr, nullptr);
  } else {
    app_indicator_set_label(self->indicator, title, nullptr);
  }
}

static void release_tray(TrayPlugin* self) {
  if (self->indicator != nullptr) {
    app_indicator_set_status(self->indicator, APP_INDICATOR_STATUS_PASSIVE);
    g_object_unref(self->indicator);
    self->indicator = nullptr;
  }
  if (self->menu != nullptr) {
    GtkWidget* menu = self->menu;
    self->menu = nullptr;
    gtk_widget_destroy(menu);
    g_object_unref(menu);
  }
}

static FlMethodResponse* handle_show(TrayPlugin* self, FlValue* args) {
  const char* id = string_value(args, "id");
  FlValue* icon = fl_value_lookup_string(args, "icon");
  const char* icon_path = string_value(icon, "path");
  if (id == nullptr || icon_path == nullptr ||
      !g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
    return respond(false);
  }

  const bool is_new = self->indicator == nullptr;
  if (is_new) {
    self->indicator =
        app_indicator_new(id, icon_path, APP_INDICATOR_CATEGORY_APPLICATION_STATUS);
  }

  attach_menu(self, fl_value_lookup_string(args, "menu"));

  if (!is_new) {
    app_indicator_set_status(self->indicator, APP_INDICATOR_STATUS_PASSIVE);
  }

  app_indicator_set_icon_full(self->indicator, icon_path, "");

  const char* tool_tip = string_value(args, "toolTip");
  if (tool_tip != nullptr) {
    app_indicator_set_title(self->indicator, tool_tip);
  }

  apply_title(self, string_value(args, "title"));

  app_indicator_set_status(self->indicator, APP_INDICATOR_STATUS_ACTIVE);

  return respond(true);
}

static FlMethodResponse* handle_set_title(TrayPlugin* self, FlValue* args) {
  if (self->indicator == nullptr) {
    return respond(false);
  }
  apply_title(self, string_value(args, "title"));
  return respond(true);
}

static FlMethodResponse* handle_update_menu_item(TrayPlugin* self,
                                                 FlValue* args) {
  const char* key = string_value(args, "key");
  if (self->menu == nullptr || key == nullptr) {
    return respond(false);
  }
  GtkWidget* item = find_menu_item(self->menu, key);
  if (item == nullptr) {
    return respond(false);
  }

  const char* label = string_value(args, "label");
  if (label != nullptr) {
    gtk_menu_item_set_label(GTK_MENU_ITEM(item), label);
  }
  bool enabled = false;
  if (bool_value_if_present(args, "enabled", &enabled)) {
    gtk_widget_set_sensitive(item, enabled);
  }
  bool checked = false;
  if (GTK_IS_CHECK_MENU_ITEM(item) &&
      bool_value_if_present(args, "checked", &checked)) {
    gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(item), checked);
  }
  return respond(true);
}

static FlMethodResponse* handle_hide(TrayPlugin* self) {
  release_tray(self);
  return respond(true);
}

static void tray_plugin_handle_method_call(TrayPlugin* self,
                                           FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "show") == 0) {
    response = handle_show(self, args);
  } else if (strcmp(method, "setTitle") == 0) {
    response = handle_set_title(self, args);
  } else if (strcmp(method, "updateMenuItem") == 0) {
    response = handle_update_menu_item(self, args);
  } else if (strcmp(method, "hide") == 0) {
    response = handle_hide(self);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void tray_plugin_dispose(GObject* object) {
  TrayPlugin* self = TRAY_PLUGIN(object);

  release_tray(self);
  if (self->session_bus != nullptr && self->session_bus_filter_id != 0) {
    g_dbus_connection_remove_filter(self->session_bus,
                                    self->session_bus_filter_id);
    self->session_bus_filter_id = 0;
  }
  g_clear_object(&self->session_bus);
  g_clear_pointer(&self->pending_activation_token, g_free);
  g_clear_object(&self->channel);
  g_clear_object(&self->registrar);

  if (active_plugin == self) {
    active_plugin = nullptr;
  }

  G_OBJECT_CLASS(tray_plugin_parent_class)->dispose(object);
}

static void tray_plugin_class_init(TrayPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = tray_plugin_dispose;
}

static void tray_plugin_init(TrayPlugin* self) {
  self->registrar = nullptr;
  self->channel = nullptr;
  self->indicator = nullptr;
  self->menu = nullptr;
  self->session_bus = nullptr;
  self->session_bus_filter_id = 0;
  self->pending_activation_token = nullptr;
}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  tray_plugin_handle_method_call(TRAY_PLUGIN(user_data), method_call);
}

void tray_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  if (active_plugin != nullptr) {
    return;
  }

  TrayPlugin* plugin =
      TRAY_PLUGIN(g_object_new(tray_plugin_get_type(), nullptr));
  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "tray",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  plugin->session_bus = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, nullptr);
  if (plugin->session_bus != nullptr) {
    plugin->session_bus_filter_id = g_dbus_connection_add_filter(
        plugin->session_bus, session_bus_filter, nullptr, nullptr);
  }

  active_plugin = plugin;

  g_object_unref(plugin);
}

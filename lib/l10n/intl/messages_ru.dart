// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ru locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'ru';

  static String m0(code) =>
      "Windows отказалась запускать FlClashCore.exe (ошибка ${code}). Политики контроля приложений, такие как Smart App Control или AppLocker, блокируют неподписанные программы; разрешите FlClash в этой политике или отключите её и повторите попытку.";

  static String m1(url) => "Создать профиль по ссылке ${url}?";

  static String m2(count) =>
      "${Intl.plural(count, one: '${count} день назад', few: '${count} дня назад', many: '${count} дней назад', other: '${count} дня назад')}";

  static String m3(label) =>
      "Вы уверены, что хотите удалить выбранные элементы (${label})?";

  static String m4(label) => "Вы уверены, что хотите удалить «${label}»?";

  static String m5(label) => "Сведения о ${label}";

  static String m6(label) => "Поле «${label}» не может быть пустым";

  static String m7(count) =>
      "${Intl.plural(count, one: '${count} запись', few: '${count} записи', many: '${count} записей', other: '${count} записи')}";

  static String m8(label) => "«${label}» уже существует";

  static String m9(name) => "${name}: уже последняя версия";

  static String m10(name) => "${name}: обновлено";

  static String m11(name) => "Обновление ${name}...";

  static String m12(action) =>
      "Уже используется для «${action}». При сохранении будет перенесено сюда.";

  static String m13(modifiers) =>
      "Добавьте хотя бы одну из клавиш: ${modifiers}";

  static String m14(count) =>
      "${Intl.plural(count, one: '${count} час назад', few: '${count} часа назад', many: '${count} часов назад', other: '${count} часа назад')}";

  static String m15(count) =>
      "${Intl.plural(count, one: '${count} час', few: '${count} часа', many: '${count} часов', other: '${count} часа')}";

  static String m16(target) => "${target} — недопустимая политика";

  static String m17(proxyName) => "${proxyName} — недопустимый прокси";

  static String m18(providerName) =>
      "${providerName} — недопустимый провайдер прокси";

  static String m19(subRule) => "${subRule} — недопустимый SUB_RULE";

  static String m20(appName) =>
      "1. Откройте Системные настройки > Конфиденциальность и безопасность\n2. Выберите Службы геолокации\n3. Найдите ${appName} в списке справа и установите флажок\n\nПосле завершения настройки вернитесь в приложение и продолжайте работу. Спасибо за содействие.";

  static String m21(label, max) => "«${label}» — не более ${max} символов";

  static String m22(count) =>
      "${Intl.plural(count, one: '${count} минуту назад', few: '${count} минуты назад', many: '${count} минут назад', other: '${count} минуты назад')}";

  static String m23(count) =>
      "${Intl.plural(count, one: '${count} месяц назад', few: '${count} месяца назад', many: '${count} месяцев назад', other: '${count} месяца назад')}";

  static String m24(label) => "Пока нет: ${label}";

  static String m25(label) => "Значение «${label}» должно быть числом";

  static String m26(label) =>
      "${label} должен быть числом от 1024 до 49151, 0 для отключения";

  static String m27(count) => "${count} прокси";

  static String m28(maximum) => "Введите целое число от 0 до ${maximum}.";

  static String m29(count) =>
      "${Intl.plural(count, one: '${count} правило', few: '${count} правила', many: '${count} правил', other: '${count} правила')}";

  static String m30(count) =>
      "${Intl.plural(count, one: '${count} секунда', few: '${count} секунды', many: '${count} секунд', other: '${count} секунды')}";

  static String m31(count) => "Выбрано: ${count}";

  static String m32(interval, idleInterval) =>
      "${interval} · бездействие ${idleInterval}";

  static String m33(interval) => "${interval} · бездействие отключено";

  static String m34(label) => "Значение «${label}» должно быть URL";

  static String m35(count) =>
      "${Intl.plural(count, one: '${count} год назад', few: '${count} года назад', many: '${count} лет назад', other: '${count} года назад')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("О программе"),
    "accessControl": MessageLookupByLibrary.simpleMessage("Контроль доступа"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Через VPN проходят только выбранные приложения",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "Выбор приложений, использующих прокси",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "Контроль доступа приложений отключён",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Выбранные приложения исключаются из VPN",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage(
      "Настройки контроля доступа",
    ),
    "accessDenied": MessageLookupByLibrary.simpleMessage("Доступ запрещён"),
    "account": MessageLookupByLibrary.simpleMessage("Аккаунт"),
    "action": MessageLookupByLibrary.simpleMessage("Действие"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage(
      "Проверить все задержки",
    ),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("Прямой режим"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage(
      "Глобальный режим",
    ),
    "actionMode": MessageLookupByLibrary.simpleMessage("Переключить режим"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("Системный прокси"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("Режим правил"),
    "actionStart": MessageLookupByLibrary.simpleMessage("Старт/Стоп"),
    "actionTun": MessageLookupByLibrary.simpleMessage("TUN"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage(
      "Обновить профили",
    ),
    "actionView": MessageLookupByLibrary.simpleMessage("Показать/Скрыть"),
    "add": MessageLookupByLibrary.simpleMessage("Добавить"),
    "addProfile": MessageLookupByLibrary.simpleMessage("Добавить профиль"),
    "addProxies": MessageLookupByLibrary.simpleMessage("Добавить прокси"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Добавить группу прокси",
    ),
    "addProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Добавить провайдеров прокси",
    ),
    "addRule": MessageLookupByLibrary.simpleMessage("Добавить правило"),
    "addSsid": MessageLookupByLibrary.simpleMessage("Добавить SSID"),
    "addWidget": MessageLookupByLibrary.simpleMessage("Добавить виджет"),
    "addedRules": MessageLookupByLibrary.simpleMessage("Добавленные правила"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage(
      "Дополнительные параметры",
    ),
    "address": MessageLookupByLibrary.simpleMessage("Адрес"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("Адрес сервера WebDAV"),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Введите корректный адрес WebDAV",
    ),
    "advancedConfig": MessageLookupByLibrary.simpleMessage(
      "Расширенная конфигурация",
    ),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Разнообразные параметры конфигурации",
    ),
    "ageKeyGenerateTitle": MessageLookupByLibrary.simpleMessage(
      "Генерация ключа Age",
    ),
    "ageKeyPairGeneratedSuccess": MessageLookupByLibrary.simpleMessage(
      "Пара ключей X25519 создана, сохраните ее в надежном месте",
    ),
    "agePrivateKeyLabel": MessageLookupByLibrary.simpleMessage(
      "Закрытый ключ Age",
    ),
    "agePrivateKeyRequired": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, сначала введите корректный закрытый ключ Age",
    ),
    "agePublicKeyLabel": MessageLookupByLibrary.simpleMessage(
      "Открытый ключ Age",
    ),
    "ageSecretKeyInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, введите корректный приватный ключ Age (должен начинаться с AGE-SECRET-KEY-)",
    ),
    "ageSecretKeyOptional": MessageLookupByLibrary.simpleMessage(
      "Приватный ключ Age (необязательно)",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("Согласен"),
    "allData": MessageLookupByLibrary.simpleMessage("Все данные"),
    "allowBypass": MessageLookupByLibrary.simpleMessage(
      "Разрешить приложениям обходить VPN",
    ),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "При включении некоторые приложения смогут обходить VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("Разрешить LAN"),
    "allowLanAccess": MessageLookupByLibrary.simpleMessage(
      "Разрешить доступ из LAN",
    ),
    "allowLanAccessDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить доступ к внешнему контроллеру из локальной сети",
    ),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить доступ к прокси из локальной сети",
    ),
    "alwaysOn": MessageLookupByLibrary.simpleMessage("Всегда включён"),
    "alwaysOnDesc": MessageLookupByLibrary.simpleMessage(
      "Поддерживать VPN-подключение в любых сетевых условиях",
    ),
    "answers": MessageLookupByLibrary.simpleMessage("Ответы"),
    "app": MessageLookupByLibrary.simpleMessage("Приложение"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "Контроль доступа приложений",
    ),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage(
      "Добавлять системный DNS",
    ),
    "appendSystemDnsTip": MessageLookupByLibrary.simpleMessage(
      "Принудительно добавлять системный DNS в конфигурацию",
    ),
    "application": MessageLookupByLibrary.simpleMessage("Приложение"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage(
      "Настройки, связанные с приложением",
    ),
    "ascending": MessageLookupByLibrary.simpleMessage("По возрастанию"),
    "authentication": MessageLookupByLibrary.simpleMessage("Аутентификация"),
    "authenticationDesc": MessageLookupByLibrary.simpleMessage(
      "Требовать учётные данные для локального порта прокси, чтобы другие приложения не могли использовать его",
    ),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Не применяется, пока включена аутентификация",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("Разрешить"),
    "authorized": MessageLookupByLibrary.simpleMessage("Разрешено"),
    "auto": MessageLookupByLibrary.simpleMessage("Авто"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Автопроверка обновлений",
    ),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматически проверять обновления при запуске приложения",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Автозакрытие соединений",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматически закрывать соединения после смены узла",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Автозапуск"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Запускаться автоматически при старте системы",
    ),
    "autoRun": MessageLookupByLibrary.simpleMessage("Автовключение"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Включаться автоматически при открытии приложения",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("Автообновление"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал автообновления (минуты)",
    ),
    "back": MessageLookupByLibrary.simpleMessage("Назад"),
    "backToDashboard": MessageLookupByLibrary.simpleMessage(
      "Возврат на главную",
    ),
    "backToDashboardDesc": MessageLookupByLibrary.simpleMessage(
      "Перед выходом возвращаться на панель",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("Резервное копирование"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage(
      "Резервное копирование и восстановление",
    ),
    "backupAndRestoreDesc": MessageLookupByLibrary.simpleMessage(
      "Синхронизация данных через WebDAV или файлы",
    ),
    "backupDateDescription": MessageLookupByLibrary.simpleMessage(
      "Местная дата (YYYY-MM-DD)",
    ),
    "backupPlatformDescription": MessageLookupByLibrary.simpleMessage(
      "Текущая платформа",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage(
      "Резервная копия создана",
    ),
    "backupTimeDescription": MessageLookupByLibrary.simpleMessage(
      "Местное время (HHmmss)",
    ),
    "backupVersionDescription": MessageLookupByLibrary.simpleMessage(
      "Версия приложения",
    ),
    "basicConfig": MessageLookupByLibrary.simpleMessage("Базовая конфигурация"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Глобальное изменение базовой конфигурации",
    ),
    "basicInfo": MessageLookupByLibrary.simpleMessage("Основная информация"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("Базовые политики"),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "Чтобы обеспечить работу в фоне, отключите оптимизацию батареи для этого приложения. Нажмите, чтобы перейти к настройкам.",
    ),
    "batteryOptimizationStatusTip": MessageLookupByLibrary.simpleMessage(
      "Из-за системных ограничений во время работы невозможно корректно получить статус оптимизации батареи",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("Привязать"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage(
      "Режим чёрного списка",
    ),
    "blockConnection": MessageLookupByLibrary.simpleMessage(
      "Заблокировать соединение",
    ),
    "browse": MessageLookupByLibrary.simpleMessage("Обзор"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Исключённые домены"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Действует только при включённом системном прокси",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("Кэш"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "Кэш повреждён. Очистить его?",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Отмена"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("Снять выделение"),
    "captureDns": MessageLookupByLibrary.simpleMessage(
      "Перехват системного DNS",
    ),
    "captureDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Перенаправлять все системные DNS-запросы во внутренний модуль DNS",
    ),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "Не удалось переключить прокси; восстановлен предыдущий выбор",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage(
      "Важные изменения",
    ),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("Новые функции"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage("Исправления"),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage(
      "Производительность",
    ),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("Откаты"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage(
      "Проверять TLS-сертификаты",
    ),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "Отклонять недоверенные сертификаты. Отключение подвергает подписки и резервные копии атаке «человек посередине»",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("Проверить обновления"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "У вас уже последняя версия",
    ),
    "clear": MessageLookupByLibrary.simpleMessage("Очистить"),
    "clearData": MessageLookupByLibrary.simpleMessage("Очистить данные"),
    "clearSearch": MessageLookupByLibrary.simpleMessage("Очистить поиск"),
    "clipboardExport": MessageLookupByLibrary.simpleMessage(
      "Экспорт в буфер обмена",
    ),
    "clipboardImport": MessageLookupByLibrary.simpleMessage(
      "Импорт из буфера обмена",
    ),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось записать в буфер обмена",
    ),
    "close": MessageLookupByLibrary.simpleMessage("Закрыть"),
    "closeAll": MessageLookupByLibrary.simpleMessage("Закрыть все"),
    "closeConnections": MessageLookupByLibrary.simpleMessage(
      "Закрыть соединения",
    ),
    "closeConnectionsPrompt": MessageLookupByLibrary.simpleMessage(
      "Закрыть соединения, использующие предыдущий прокси?",
    ),
    "collapse": MessageLookupByLibrary.simpleMessage("Свернуть"),
    "collapseProxyChains": MessageLookupByLibrary.simpleMessage(
      "Сворачивать цепочки прокси",
    ),
    "collapseProxyChainsDesc": MessageLookupByLibrary.simpleMessage(
      "Скрывать промежуточные узлы, если в цепочке прокси больше трёх узлов",
    ),
    "collapseQuickSettingsPanel": MessageLookupByLibrary.simpleMessage(
      "Сворачивать панель быстрых настроек",
    ),
    "collapseQuickSettingsPanelDesc": MessageLookupByLibrary.simpleMessage(
      "Сворачивать панель быстрых настроек после нажатия плитки",
    ),
    "color": MessageLookupByLibrary.simpleMessage("Цвет"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("Цветовые схемы"),
    "columns": MessageLookupByLibrary.simpleMessage("Столбцы"),
    "compatible": MessageLookupByLibrary.simpleMessage("Режим совместимости"),
    "configDataDetected": MessageLookupByLibrary.simpleMessage(
      "В конфигурации обнаружены данные",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("Подтвердить"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите удалить все данные?",
    ),
    "confirmClearSelectedData": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите удалить выбранные данные?",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите удалить эту группу прокси?",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите закрыть текущее окно?",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите принудительно завершить ядро со сбоем?",
    ),
    "confirmOverwriteTip": MessageLookupByLibrary.simpleMessage(
      "После подтверждения существующие данные будут перезаписаны",
    ),
    "congestionController": MessageLookupByLibrary.simpleMessage(
      "Управление перегрузкой",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("Подключено"),
    "connecting": MessageLookupByLibrary.simpleMessage("Подключение"),
    "connection": MessageLookupByLibrary.simpleMessage("Соединение"),
    "connectionInfo": MessageLookupByLibrary.simpleMessage(
      "Количество подключений",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("Соединения"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Просмотр данных о текущих соединениях",
    ),
    "connectivity": MessageLookupByLibrary.simpleMessage("Подключение: "),
    "content": MessageLookupByLibrary.simpleMessage("Содержимое"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Содержимое не может быть пустым",
    ),
    "contentScheme": MessageLookupByLibrary.simpleMessage("Контентная"),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "Управление глобальными добавленными правилами",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Копировать"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Копировать переменные окружения",
    ),
    "copyLink": MessageLookupByLibrary.simpleMessage("Копировать ссылку"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Скопировано"),
    "core": MessageLookupByLibrary.simpleMessage("Ядро"),
    "coreBlockedByPolicyTip": m0,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "Smart App Control в Windows заблокировал неподписанный FlClashCore.exe. Откройте Безопасность Windows → Управление приложениями и браузером → Параметры Smart App Control, выберите «Выкл.» и снова запустите FlClash. Повторно включить Smart App Control без переустановки Windows нельзя.",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("Статус ядра"),
    "country": MessageLookupByLibrary.simpleMessage("Регион"),
    "crashTest": MessageLookupByLibrary.simpleMessage("Тест сбоя"),
    "create": MessageLookupByLibrary.simpleMessage("Создать"),
    "createProfile": MessageLookupByLibrary.simpleMessage("Создать профиль"),
    "createProfileFromUrlTip": m1,
    "creationTime": MessageLookupByLibrary.simpleMessage("Время создания"),
    "custom": MessageLookupByLibrary.simpleMessage("Вручную"),
    "cut": MessageLookupByLibrary.simpleMessage("Вырезать"),
    "dark": MessageLookupByLibrary.simpleMessage("Тёмная"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Панель"),
    "dataChangedSave": MessageLookupByLibrary.simpleMessage(
      "Обнаружены изменения данных. Сохранить их?",
    ),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "Не удалось сохранить изменение; оно отменено",
    ),
    "davDirectory": MessageLookupByLibrary.simpleMessage("Каталог"),
    "daysAgo": m2,
    "defaultNameserver": MessageLookupByLibrary.simpleMessage(
      "DNS-сервер по умолчанию",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Используется для разрешения адресов DNS-серверов",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("По умолчанию"),
    "delay": MessageLookupByLibrary.simpleMessage("Задержка"),
    "delayTest": MessageLookupByLibrary.simpleMessage("Тест задержки"),
    "delete": MessageLookupByLibrary.simpleMessage("Удалить"),
    "deleteMultipTip": m3,
    "deleteTip": m4,
    "desc": MessageLookupByLibrary.simpleMessage(
      "Многоплатформенный прокси-клиент на основе mihomo, простой и удобный в использовании, с открытым исходным кодом и без рекламы.",
    ),
    "descending": MessageLookupByLibrary.simpleMessage("По убыванию"),
    "destination": MessageLookupByLibrary.simpleMessage("Назначение"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "GeoIP назначения",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage(
      "ASN IP назначения",
    ),
    "details": m5,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Использует сторонний API; только для справки",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Режим разработчика"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Режим разработчика включён.",
    ),
    "dialerProxy": MessageLookupByLibrary.simpleMessage(
      "Прокси для подключения",
    ),
    "dialerProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Исход, через который идёт обращение к NTP-серверу",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("Прямой"),
    "disableUDP": MessageLookupByLibrary.simpleMessage("Отключить UDP"),
    "disclaimer": MessageLookupByLibrary.simpleMessage(
      "Отказ от ответственности",
    ),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "Это программное обеспечение предназначено только для некоммерческого использования: обучения, обмена опытом и научных исследований. Коммерческое использование строго запрещено; любая коммерческая деятельность не имеет отношения к этому программному обеспечению.",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("Отключено"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "Доступна новая версия",
    ),
    "dnsDesc": MessageLookupByLibrary.simpleMessage(
      "Настройки, связанные с DNS",
    ),
    "dnsHijack": MessageLookupByLibrary.simpleMessage("Перехват DNS"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "Перенаправлять DNS-запросы во внутренний модуль DNS",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("Перехват DNS"),
    "dnsIPv6Desc": MessageLookupByLibrary.simpleMessage(
      "Если выключено, запросы AAAA возвращают пустой результат",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("Режим DNS"),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("DNS-запросы"),
    "dnsQueriesDesc": MessageLookupByLibrary.simpleMessage(
      "Записи DNS-разрешения ядра",
    ),
    "domain": MessageLookupByLibrary.simpleMessage("Домен"),
    "download": MessageLookupByLibrary.simpleMessage("Загрузка"),
    "downloadSpeed": MessageLookupByLibrary.simpleMessage(
      "Скорость скачивания",
    ),
    "downloadTraffic": MessageLookupByLibrary.simpleMessage("Входящий трафик"),
    "easyTierConnectionLatency": MessageLookupByLibrary.simpleMessage(
      "Задержка соединения",
    ),
    "easyTierDnsZone": MessageLookupByLibrary.simpleMessage("DNS-зона"),
    "easyTierFeatureFlags": MessageLookupByLibrary.simpleMessage(
      "Флаги функций",
    ),
    "easyTierInstanceId": MessageLookupByLibrary.simpleMessage("ID экземпляра"),
    "easyTierLatencyFirstPathLatency": MessageLookupByLibrary.simpleMessage(
      "Задержка пути (приоритет задержки)",
    ),
    "easyTierListeners": MessageLookupByLibrary.simpleMessage(
      "Адреса прослушивания",
    ),
    "easyTierLocalEndpoint": MessageLookupByLibrary.simpleMessage(
      "Локальная конечная точка",
    ),
    "easyTierLossRate": MessageLookupByLibrary.simpleMessage("Потери пакетов"),
    "easyTierMinDirectLatency": MessageLookupByLibrary.simpleMessage(
      "Минимальная задержка прямого соединения",
    ),
    "easyTierNextHop": MessageLookupByLibrary.simpleMessage(
      "ID следующего узла",
    ),
    "easyTierPathLatency": MessageLookupByLibrary.simpleMessage(
      "Задержка пути (приоритет числа переходов)",
    ),
    "easyTierPeerId": MessageLookupByLibrary.simpleMessage("ID узла"),
    "easyTierProtocol": MessageLookupByLibrary.simpleMessage(
      "Транспортный протокол",
    ),
    "easyTierPublicServer": MessageLookupByLibrary.simpleMessage(
      "Публичный сервер",
    ),
    "easyTierRemoteEndpoint": MessageLookupByLibrary.simpleMessage(
      "Удалённая конечная точка",
    ),
    "easyTierRouteCost": MessageLookupByLibrary.simpleMessage(
      "Стоимость маршрута",
    ),
    "easyTierRxPackets": MessageLookupByLibrary.simpleMessage(
      "Получено пакетов",
    ),
    "easyTierTxPackets": MessageLookupByLibrary.simpleMessage(
      "Отправлено пакетов",
    ),
    "edit": MessageLookupByLibrary.simpleMessage("Редактировать"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage(
      "Редактировать глобальные правила",
    ),
    "editProxy": MessageLookupByLibrary.simpleMessage("Редактировать прокси"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Редактировать группу прокси",
    ),
    "editRule": MessageLookupByLibrary.simpleMessage("Редактировать правило"),
    "editSsid": MessageLookupByLibrary.simpleMessage("Изменить SSID"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage(
      "Редактор недоступен",
    ),
    "emptyTip": m6,
    "en": MessageLookupByLibrary.simpleMessage("Английский"),
    "enableExternalController": MessageLookupByLibrary.simpleMessage(
      "Включить внешний контроллер",
    ),
    "endpointIndependentNat": MessageLookupByLibrary.simpleMessage(
      "Улучшенный NAT",
    ),
    "endpointIndependentNatDesc": MessageLookupByLibrary.simpleMessage(
      "Оптимизировать подключения приложений UDP и P2P",
    ),
    "endpoints": MessageLookupByLibrary.simpleMessage("Конечные точки"),
    "enforceRoutes": MessageLookupByLibrary.simpleMessage(
      "Принудительная маршрутизация",
    ),
    "enforceRoutesDesc": MessageLookupByLibrary.simpleMessage(
      "Направлять трафик через туннель, даже если существуют более конкретные маршруты",
    ),
    "entries": MessageLookupByLibrary.simpleMessage(" записей"),
    "entriesCount": m7,
    "error": MessageLookupByLibrary.simpleMessage("Ошибка"),
    "exclude": MessageLookupByLibrary.simpleMessage("Скрыть из недавних задач"),
    "excludeAPNs": MessageLookupByLibrary.simpleMessage("Исключить APNs"),
    "excludeAPNsDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить трафику Apple Push-уведомлений обходить туннель",
    ),
    "excludeCellularServices": MessageLookupByLibrary.simpleMessage(
      "Исключить сотовые сервисы",
    ),
    "excludeCellularServicesDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить трафику сотовых сервисов, таких как Wi-Fi вызовы, обходить туннель",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "Скрывать приложение из недавних задач, когда оно в фоне",
    ),
    "excludeDeviceCommunication": MessageLookupByLibrary.simpleMessage(
      "Исключить межустройственную связь",
    ),
    "excludeDeviceCommunicationDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить трафику AirDrop, AirPlay и другой межустройственной связи обходить туннель",
    ),
    "excludeLocalNetworks": MessageLookupByLibrary.simpleMessage(
      "Исключить локальные сети",
    ),
    "excludeLocalNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить прямой доступ к устройствам в локальной сети",
    ),
    "excludeProxyFilter": MessageLookupByLibrary.simpleMessage(
      "Фильтр исключения узлов",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("Исключённые SSID"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "При подключении к Wi-Fi с исключённым SSID состояние работы приложения переключается автоматически",
    ),
    "excludeType": MessageLookupByLibrary.simpleMessage("Исключаемые типы"),
    "existsTip": m8,
    "exit": MessageLookupByLibrary.simpleMessage("Выход"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage(
      "Выйти из полноэкранного режима",
    ),
    "expand": MessageLookupByLibrary.simpleMessage("Развернуть"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("Ожидаемый статус"),
    "expireTime": MessageLookupByLibrary.simpleMessage("Срок действия"),
    "exportFile": MessageLookupByLibrary.simpleMessage("Экспорт файла"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Экспорт логов"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("Экспорт выполнен"),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("Экспрессивная"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "Внешний контроллер",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Настройка внешнего доступа к ядру Mihomo",
    ),
    "externalFetch": MessageLookupByLibrary.simpleMessage("Внешнее получение"),
    "externalLink": MessageLookupByLibrary.simpleMessage("Внешняя ссылка"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("Очень крупный"),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Фильтр Fake-IP"),
    "fakeipFilterDesc": MessageLookupByLibrary.simpleMessage(
      "Совпавшие домены в режиме Fake IP получают реальные IP-адреса вместо Fake IP",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Диапазон Fake-IP"),
    "fallback": MessageLookupByLibrary.simpleMessage("Fallback"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Обычно зарубежный DNS",
    ),
    "fallbackDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Совпавшие домены используют fallback напрямую, без запроса к nameserver",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Фильтр fallback"),
    "fallbackGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Проверяет результаты nameserver по коду GeoIP; для адресов вне этого региона используется fallback",
    ),
    "fallbackGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Домены из этих категорий GeoSite напрямую используют fallback",
    ),
    "fallbackIpcidrDesc": MessageLookupByLibrary.simpleMessage(
      "Результаты nameserver из этих префиксов CIDR заменяются результатами fallback",
    ),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("Точная передача"),
    "file": MessageLookupByLibrary.simpleMessage("Файл"),
    "fileDesc": MessageLookupByLibrary.simpleMessage(
      "Загрузить файл профиля напрямую",
    ),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "Файл изменён. Сохранить изменения?",
    ),
    "fileName": MessageLookupByLibrary.simpleMessage("Имя файла"),
    "filter": MessageLookupByLibrary.simpleMessage("Фильтр"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("Поиск процесса"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "При включении возможна небольшая потеря производительности",
    ),
    "followProfile": MessageLookupByLibrary.simpleMessage("Как в профиле"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("Шрифт"),
    "fontSize": MessageLookupByLibrary.simpleMessage("Размер"),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите принудительно перезапустить ядро?",
    ),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("Фруктовый микс"),
    "general": MessageLookupByLibrary.simpleMessage("Общие"),
    "generalDesc": MessageLookupByLibrary.simpleMessage(
      "Общие настройки приложения и ядра",
    ),
    "generateFromPrivateKey": MessageLookupByLibrary.simpleMessage(
      "Создать из закрытого ключа Age",
    ),
    "generateSecret": MessageLookupByLibrary.simpleMessage("Создать"),
    "geoAutoUpdate": MessageLookupByLibrary.simpleMessage("Автообновление"),
    "geoAutoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал автообновления",
    ),
    "geoAutoUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "Интервал автообновления должен быть больше 0",
    ),
    "geoOptions": MessageLookupByLibrary.simpleMessage("Настройки Geo"),
    "geoResources": MessageLookupByLibrary.simpleMessage("Ресурсы Geo"),
    "geoSkipped": m9,
    "geoUpdated": m10,
    "geoUpdating": m11,
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Geo: экономия памяти",
    ),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "При включении используется Geo-загрузчик с низким потреблением памяти",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("Код GeoIP"),
    "geositeMatcher": MessageLookupByLibrary.simpleMessage(
      "Высокопроизводительный Geo-сопоставитель",
    ),
    "geositeMatcherDesc": MessageLookupByLibrary.simpleMessage(
      "При включении для сопоставления используется алгоритм минимального совершенного хеша",
    ),
    "global": MessageLookupByLibrary.simpleMessage("Глобальный"),
    "go": MessageLookupByLibrary.simpleMessage("Перейти"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Скачать"),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage(
      "Перейти к настройке скрипта",
    ),
    "goroutineInfo": MessageLookupByLibrary.simpleMessage("Количество горутин"),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "Кэшировать изменения?",
    ),
    "header": MessageLookupByLibrary.simpleMessage("Заголовок"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Служба Helper недоступна, поэтому TUN-режим включить нельзя. Переустановите FlClash.",
    ),
    "hide": MessageLookupByLibrary.simpleMessage("Скрыть"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("Скрыть из списка"),
    "hidePassword": MessageLookupByLibrary.simpleMessage("Скрыть пароль"),
    "hideUnavailable": MessageLookupByLibrary.simpleMessage("Скрыть таймаут"),
    "highPriorityAutoLaunch": MessageLookupByLibrary.simpleMessage(
      "Автозапуск с высоким приоритетом",
    ),
    "highPriorityAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать задачу Windows для более раннего запуска",
    ),
    "host": MessageLookupByLibrary.simpleMessage("Хост"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("Добавить записи hosts"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage(
      "Конфликт горячих клавиш",
    ),
    "hotkeyConflictWith": m12,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "Глобальные горячие клавиши работают, даже когда окно скрыто. Нажмите на действие, чтобы записать сочетание клавиш.",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("Горячие клавиши"),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "Управление приложением с клавиатуры",
    ),
    "hotkeyNeedsModifier": m13,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("Не задано"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "Не зарегистрировано: сочетание может быть занято другим приложением",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("часов"),
    "hoursAgo": m14,
    "hoursCount": m15,
    "icmpForwarding": MessageLookupByLibrary.simpleMessage("Пересылка ICMP"),
    "icmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "Включить поддержку ICMP Ping",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("Значок"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("История значков"),
    "iconSource": MessageLookupByLibrary.simpleMessage("Источник иконки"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Стиль значков"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("URL значка"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Игнорировать оптимизацию батареи",
    ),
    "ignoreCertificateErrors": MessageLookupByLibrary.simpleMessage(
      "Игнорировать проверку сертификатов",
    ),
    "ignoreCertificateErrorsDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить HTTPS-соединения с недействительными сертификатами. Это снижает безопасность",
    ),
    "import": MessageLookupByLibrary.simpleMessage("Импорт"),
    "importFile": MessageLookupByLibrary.simpleMessage("Импорт из файла"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("Импорт из URL"),
    "importUrl": MessageLookupByLibrary.simpleMessage("Импорт по URL"),
    "inbound": MessageLookupByLibrary.simpleMessage("Входящие"),
    "includeAllNetworks": MessageLookupByLibrary.simpleMessage(
      "Включить все сети",
    ),
    "includeAllNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "Маршрутизировать весь сетевой трафик через туннель, включая локальные и сотовые сервисы",
    ),
    "includeAllProxies": MessageLookupByLibrary.simpleMessage(
      "Включить все прокси",
    ),
    "includeAllProxiesTip": MessageLookupByLibrary.simpleMessage(
      "Подключает все прокси вне групп; ниже можно добавить дополнительные группы прокси",
    ),
    "includeAllProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Включить всех провайдеров прокси",
    ),
    "includeAllProxyProvidersTip": MessageLookupByLibrary.simpleMessage(
      "При включении переопределяет подключённых провайдеров прокси",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("Бессрочно"),
    "init": MessageLookupByLibrary.simpleMessage("Инициализация"),
    "initialize": MessageLookupByLibrary.simpleMessage("Инициализировать"),
    "initiator": MessageLookupByLibrary.simpleMessage("Источник"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "Введите корректную горячую клавишу",
    ),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "Введите название группы прокси",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage(
      "Введите содержимое правила",
    ),
    "installedAppsPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "Разрешение на список приложений отклонено, поэтому установленные приложения недоступны. Предоставьте его вручную в системных настройках.",
    ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Эта система не выдаёт список установленных приложений без разрешения. Предоставьте его, чтобы настроить прокси для отдельных приложений.",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Требуется разрешение на список приложений",
    ),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("Умный выбор"),
    "interfaceName": MessageLookupByLibrary.simpleMessage("Имя интерфейса"),
    "interfaceNameDesc": MessageLookupByLibrary.simpleMessage(
      "Сетевой интерфейс для исходящих соединений",
    ),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage(
      "Исходящий интерфейс",
    ),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("Очистить"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage("Вручную"),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage(
      "Как в конфигурации",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Интернет"),
    "interval": MessageLookupByLibrary.simpleMessage("Интервал"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("Внутренний IP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage(
      "Недопустимый файл резервной копии",
    ),
    "invalidBackupFileName": MessageLookupByLibrary.simpleMessage(
      "Введите допустимое имя файла без разделителей пути и специальных символов, длиной до 255 байт.",
    ),
    "invalidDavDirectory": MessageLookupByLibrary.simpleMessage(
      "Введите допустимый каталог без сегментов . или .., обратных косых черт и специальных символов.",
    ),
    "invalidPolicy": m16,
    "invalidProxy": m17,
    "invalidProxyProvider": m18,
    "invalidSubRule": m19,
    "ipcidr": MessageLookupByLibrary.simpleMessage("IP/CIDR"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "При включении можно принимать трафик IPv6",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить входящий IPv6",
    ),
    "ja": MessageLookupByLibrary.simpleMessage("Японский"),
    "justNow": MessageLookupByLibrary.simpleMessage("Только что"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "Интервал TCP keep-alive",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Ключ"),
    "language": MessageLookupByLibrary.simpleMessage("Язык"),
    "large": MessageLookupByLibrary.simpleMessage("Крупный"),
    "layout": MessageLookupByLibrary.simpleMessage("Макет"),
    "level": MessageLookupByLibrary.simpleMessage("Уровень"),
    "light": MessageLookupByLibrary.simpleMessage("Светлая"),
    "lineHeight": MessageLookupByLibrary.simpleMessage("Интервал"),
    "lineWrap": MessageLookupByLibrary.simpleMessage("Перенос по словам"),
    "list": MessageLookupByLibrary.simpleMessage("Список"),
    "listen": MessageLookupByLibrary.simpleMessage("Прослушивание"),
    "listeningPort": MessageLookupByLibrary.simpleMessage("Порт прослушивания"),
    "loading": MessageLookupByLibrary.simpleMessage("Загрузка..."),
    "local": MessageLookupByLibrary.simpleMessage("Локально"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Резервное копирование данных локально",
    ),
    "locationPermission": MessageLookupByLibrary.simpleMessage(
      "Разрешение на геолокацию",
    ),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "Разрешение на геолокацию отклонено, поэтому невозможно получить имя текущей сети Wi-Fi. Включите разрешение на геолокацию вручную в системных настройках.",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "По требованию системы для получения имени сети Wi-Fi необходимо разрешение на геолокацию. На Android выберите «Разрешить всегда», иначе имя сети Wi-Fi нельзя получить, пока приложение в фоне.",
    ),
    "locationPermissionGuide": m20,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Требуется разрешение на геолокацию",
    ),
    "log": MessageLookupByLibrary.simpleMessage("Лог"),
    "logLevel": MessageLookupByLibrary.simpleMessage("Уровень логов"),
    "logcat": MessageLookupByLibrary.simpleMessage("Захват логов"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "При отключении раздел логов будет скрыт",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Логи"),
    "logsDesc": MessageLookupByLibrary.simpleMessage(
      "Записи захваченных логов",
    ),
    "logsTest": MessageLookupByLibrary.simpleMessage("Тест логов"),
    "loopback": MessageLookupByLibrary.simpleMessage(
      "Инструмент разблокировки loopback",
    ),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage(
      "Для снятия ограничения loopback у UWP-приложений",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("Свободный"),
    "manual": MessageLookupByLibrary.simpleMessage("Вручную"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage(
      "Сопоставлять IP источника",
    ),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "matchTargetDesc": MessageLookupByLibrary.simpleMessage(
      "Куда направляются правила с целью MATCH-TARGET. По умолчанию — цель последнего правила MATCH этого профиля.",
    ),
    "matchTargetTitle": MessageLookupByLibrary.simpleMessage("Цель MATCH"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage(
      "Макс. число неудач",
    ),
    "maxLengthTip": m21,
    "maximize": MessageLookupByLibrary.simpleMessage("Развернуть"),
    "memoryCleanup": MessageLookupByLibrary.simpleMessage("Очистить"),
    "memoryGC": MessageLookupByLibrary.simpleMessage("Метаданные GC"),
    "memoryHeapIdle": MessageLookupByLibrary.simpleMessage(
      "Удерживаемая свободная куча",
    ),
    "memoryHeapObjects": MessageLookupByLibrary.simpleMessage("Объекты в куче"),
    "memoryHeapReleased": MessageLookupByLibrary.simpleMessage("Возвращено ОС"),
    "memoryHeapUnused": MessageLookupByLibrary.simpleMessage(
      "Свободное место в блоках кучи",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("Память"),
    "memoryMetadata": MessageLookupByLibrary.simpleMessage(
      "Метаданные среды выполнения",
    ),
    "memoryOther": MessageLookupByLibrary.simpleMessage(
      "Прочая память среды выполнения",
    ),
    "memoryReadFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось прочитать данные памяти. Повторная попытка…",
    ),
    "memoryStacks": MessageLookupByLibrary.simpleMessage("Стеки"),
    "memoryTotal": MessageLookupByLibrary.simpleMessage(
      "Использование памяти Go",
    ),
    "messageTest": MessageLookupByLibrary.simpleMessage("Тест сообщения"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("Это сообщение."),
    "min": MessageLookupByLibrary.simpleMessage("Минимальный"),
    "minimize": MessageLookupByLibrary.simpleMessage("Свернуть"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage(
      "Сворачивать при выходе",
    ),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "Изменяет стандартное поведение при выходе",
    ),
    "minutesAgo": m22,
    "mixedPort": MessageLookupByLibrary.simpleMessage("Смешанный порт"),
    "mode": MessageLookupByLibrary.simpleMessage("Режим"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Монохром"),
    "monochromeTrayIcon": MessageLookupByLibrary.simpleMessage(
      "Монохромный значок в трее",
    ),
    "monthsAgo": m23,
    "more": MessageLookupByLibrary.simpleMessage("Ещё"),
    "mtu": MessageLookupByLibrary.simpleMessage("MTU"),
    "mtuRangeTip": MessageLookupByLibrary.simpleMessage(
      "MTU должен быть целым числом от 1 до 65535",
    ),
    "multipleValuesTip": MessageLookupByLibrary.simpleMessage(
      "Разделяйте несколько значений запятыми",
    ),
    "name": MessageLookupByLibrary.simpleMessage("Название"),
    "nameserver": MessageLookupByLibrary.simpleMessage("DNS-сервер"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Используется для разрешения доменов",
    ),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Политика DNS-серверов",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Назначает DNS-серверы совпавшим доменам, категориям GeoSite или наборам правил",
    ),
    "needsLogin": MessageLookupByLibrary.simpleMessage("Требуется вход"),
    "network": MessageLookupByLibrary.simpleMessage("Сеть"),
    "networkDesc": MessageLookupByLibrary.simpleMessage(
      "Настройки, связанные с сетью",
    ),
    "networkDetection": MessageLookupByLibrary.simpleMessage("Проверка сети"),
    "networkException": MessageLookupByLibrary.simpleMessage(
      "Ошибка сети. Проверьте подключение и повторите попытку",
    ),
    "networkExtension": MessageLookupByLibrary.simpleMessage(
      "Сетевое расширение",
    ),
    "networkId": MessageLookupByLibrary.simpleMessage("Идентификатор сети"),
    "networkNotFound": MessageLookupByLibrary.simpleMessage("Сеть не найдена"),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Скорость сети"),
    "networkSpeedNotification": MessageLookupByLibrary.simpleMessage(
      "Показывать скорость сети в реальном времени",
    ),
    "networkSpeedNotificationDesc": MessageLookupByLibrary.simpleMessage(
      "Показывать скорость сети в реальном времени в области состояния системы; энергопотребление может немного увеличиться",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("Тип сети"),
    "networking": MessageLookupByLibrary.simpleMessage("Оверлейные сети"),
    "networkingDesc": MessageLookupByLibrary.simpleMessage(
      "Просмотр состояния P2P-сетей",
    ),
    "networkingError": MessageLookupByLibrary.simpleMessage("Ошибка"),
    "networkingNoOutbounds": MessageLookupByLibrary.simpleMessage(
      "В текущей конфигурации нет исходящих P2P-подключений",
    ),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("Нейтральная"),
    "newProfile": MessageLookupByLibrary.simpleMessage("Новый"),
    "newProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Создать профиль вручную",
    ),
    "nextMatch": MessageLookupByLibrary.simpleMessage("Следующее совпадение"),
    "no": MessageLookupByLibrary.simpleMessage("Нет"),
    "noData": MessageLookupByLibrary.simpleMessage("Нет данных"),
    "noDirectories": MessageLookupByLibrary.simpleMessage("Нет подкаталогов"),
    "noFilterCondition": MessageLookupByLibrary.simpleMessage(
      "Нет условий фильтрации",
    ),
    "noHotKey": MessageLookupByLibrary.simpleMessage("Горячих клавиш пока нет"),
    "noInfo": MessageLookupByLibrary.simpleMessage("Нет информации"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage(
      "Больше не напоминать",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("Нет сети"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("Приложения без сети"),
    "noRecords": MessageLookupByLibrary.simpleMessage("Записей пока нет"),
    "noRemoteBackups": MessageLookupByLibrary.simpleMessage(
      "Удалённые резервные копии не найдены",
    ),
    "noResolve": MessageLookupByLibrary.simpleMessage("Не разрешать IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage(
      "Не разрешать имя хоста",
    ),
    "nodeTrafficReadFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось получить трафик. Повторная попытка…",
    ),
    "nodeTrafficUsage": MessageLookupByLibrary.simpleMessage("Трафик узлов"),
    "nodes": MessageLookupByLibrary.simpleMessage("Узлы"),
    "none": MessageLookupByLibrary.simpleMessage("Нет"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "Текущую группу прокси нельзя выбрать",
    ),
    "ntpDesc": MessageLookupByLibrary.simpleMessage(
      "Настройки, связанные с NTP",
    ),
    "ntpInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал синхронизации (минуты)",
    ),
    "ntpStatusDesc": MessageLookupByLibrary.simpleMessage(
      "Брать время с NTP-сервера, а не из системных часов",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Профилей пока нет. Сначала добавьте профиль",
    ),
    "nullTip": m24,
    "numberTip": m25,
    "offline": MessageLookupByLibrary.simpleMessage("Не в сети"),
    "onDemand": MessageLookupByLibrary.simpleMessage("По условию"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "Настройте состояние работы приложения для определённых сценариев",
    ),
    "online": MessageLookupByLibrary.simpleMessage("В сети"),
    "onlyConfig": MessageLookupByLibrary.simpleMessage("Только конфигурация"),
    "onlyEmoji": MessageLookupByLibrary.simpleMessage("Только Emoji"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("Только значок"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Учитывать только прокси",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "При включении учитывается только трафик через прокси",
    ),
    "openInGitHub": MessageLookupByLibrary.simpleMessage("Открыть в GitHub"),
    "optional": MessageLookupByLibrary.simpleMessage("Необязательно"),
    "options": MessageLookupByLibrary.simpleMessage("Опции"),
    "other": MessageLookupByLibrary.simpleMessage("Другое"),
    "outboundMode": MessageLookupByLibrary.simpleMessage(
      "Режим исходящего трафика",
    ),
    "override": MessageLookupByLibrary.simpleMessage("Переопределение"),
    "overrideDns": MessageLookupByLibrary.simpleMessage("Переопределить DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "При включении настройки DNS профиля переопределяются",
    ),
    "overrideMode": MessageLookupByLibrary.simpleMessage(
      "Режим переопределения",
    ),
    "overrideNtp": MessageLookupByLibrary.simpleMessage("Переопределить NTP"),
    "overrideNtpDesc": MessageLookupByLibrary.simpleMessage(
      "При включении настройки NTP профиля переопределяются",
    ),
    "overrideScript": MessageLookupByLibrary.simpleMessage(
      "Скрипт переопределения",
    ),
    "overwriteTypeCustom": MessageLookupByLibrary.simpleMessage(
      "Пользовательский",
    ),
    "overwriteTypeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "Пользовательский режим: полная настройка групп прокси и правил",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("Палитра"),
    "parentDirectory": MessageLookupByLibrary.simpleMessage(
      "Родительский каталог",
    ),
    "password": MessageLookupByLibrary.simpleMessage("Пароль"),
    "paste": MessageLookupByLibrary.simpleMessage("Вставить"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage("Выбрать из галереи"),
    "pinWindow": MessageLookupByLibrary.simpleMessage(
      "Закрепить поверх всех окон",
    ),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "Привяжите WebDAV",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Введите название скрипта",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Загрузите корректный QR-код",
    ),
    "port": MessageLookupByLibrary.simpleMessage("Порт"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Введите другой порт",
    ),
    "portTip": m26,
    "positiveIntegerTip": MessageLookupByLibrary.simpleMessage(
      "Введите целое число больше 0",
    ),
    "predictiveBack": MessageLookupByLibrary.simpleMessage(
      "Предиктивный возврат",
    ),
    "preferH3": MessageLookupByLibrary.simpleMessage("Предпочитать HTTP/3"),
    "preferH3Desc": MessageLookupByLibrary.simpleMessage(
      "Предпочитать HTTP/3 для DoH",
    ),
    "prerequisites": MessageLookupByLibrary.simpleMessage(
      "Предварительные условия",
    ),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("Нажмите клавишу"),
    "preview": MessageLookupByLibrary.simpleMessage("Предпросмотр"),
    "previousMatch": MessageLookupByLibrary.simpleMessage(
      "Предыдущее совпадение",
    ),
    "process": MessageLookupByLibrary.simpleMessage("Процесс"),
    "profile": MessageLookupByLibrary.simpleMessage("Профиль"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("Введите корректный интервал"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("Введите интервал автообновления"),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "Профиль изменён. Отключить автообновление?",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Введите название профиля",
    ),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Введите корректный URL профиля",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Введите URL профиля",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Профили"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("Сортировка профилей"),
    "project": MessageLookupByLibrary.simpleMessage("Проект"),
    "promptCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Запрос на закрытие соединений",
    ),
    "promptCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Спрашивать о закрытии соединений после смены узла",
    ),
    "providers": MessageLookupByLibrary.simpleMessage("Внешние ресурсы"),
    "proxies": MessageLookupByLibrary.simpleMessage("Прокси"),
    "proxiesCount": m27,
    "proxiesEmpty": MessageLookupByLibrary.simpleMessage("Список прокси пуст"),
    "proxy": MessageLookupByLibrary.simpleMessage("Прокси"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("Цепочка прокси"),
    "proxyDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Обнаружены отклонения в выбранных прокси",
    ),
    "proxyFilter": MessageLookupByLibrary.simpleMessage("Фильтр узлов"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Группа прокси"),
    "proxyGroupDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Обнаружены отклонения в текущей группе прокси",
    ),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage(
      "Группа прокси пуста",
    ),
    "proxyGroupNameDuplicate": MessageLookupByLibrary.simpleMessage(
      "Название группы прокси уже используется",
    ),
    "proxyGroupNameEmpty": MessageLookupByLibrary.simpleMessage(
      "Название группы прокси не может быть пустым",
    ),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage(
      "DNS-сервер для прокси",
    ),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Используется для разрешения доменов прокси-узлов",
    ),
    "proxyNameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Политика прокси-сервера имен",
    ),
    "proxyNameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Указать политику сервера имен для прокси-узлов",
    ),
    "proxyProviderDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Обнаружены отклонения в выбранных провайдерах прокси",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("Провайдеры прокси"),
    "proxyProvidersEmpty": MessageLookupByLibrary.simpleMessage(
      "Список провайдеров прокси пуст",
    ),
    "proxyProvidersNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Провайдеры прокси не могут быть пустыми",
    ),
    "proxyType": MessageLookupByLibrary.simpleMessage("Тип прокси"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("Очистить кэш"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Чисто чёрный режим"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR-код"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Сканируйте QR-код, чтобы получить профиль",
    ),
    "query": MessageLookupByLibrary.simpleMessage("Запросить"),
    "queryDns": MessageLookupByLibrary.simpleMessage("DNS-запрос"),
    "queryRule": MessageLookupByLibrary.simpleMessage("Проверить правила"),
    "quickFill": MessageLookupByLibrary.simpleMessage("Быстрое заполнение"),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("Радуга"),
    "random": MessageLookupByLibrary.simpleMessage("Случайный"),
    "recentRequests": MessageLookupByLibrary.simpleMessage("Последние запросы"),
    "recordType": MessageLookupByLibrary.simpleMessage("Тип записи"),
    "recvMsgX": MessageLookupByLibrary.simpleMessage("Включить RecvMsgX"),
    "recvMsgXDesc": MessageLookupByLibrary.simpleMessage(
      "Пакетный приём пакетов в Darwin",
    ),
    "redirPort": MessageLookupByLibrary.simpleMessage("Порт Redir"),
    "redo": MessageLookupByLibrary.simpleMessage("Повторить"),
    "regexSearch": MessageLookupByLibrary.simpleMessage("Поиск по regex"),
    "relayed": MessageLookupByLibrary.simpleMessage("Через ретранслятор"),
    "remote": MessageLookupByLibrary.simpleMessage("Удалённо"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Резервное копирование данных в WebDAV",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage(
      "Удалённое назначение",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Убрать"),
    "replace": MessageLookupByLibrary.simpleMessage("Заменить"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("Заменить все"),
    "request": MessageLookupByLibrary.simpleMessage("Запрос"),
    "requests": MessageLookupByLibrary.simpleMessage("Запросы"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage(
      "Просмотр последних запросов",
    ),
    "reset": MessageLookupByLibrary.simpleMessage("Сброс"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "На этой странице есть изменения. Вы уверены, что хотите выполнить сброс?",
    ),
    "resetProfilesAndScripts": MessageLookupByLibrary.simpleMessage(
      "Профили и скрипты",
    ),
    "resetSettingsData": MessageLookupByLibrary.simpleMessage(
      "Настройки приложения",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите выполнить сброс?",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("Ресурсы"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage(
      "Сведения о внешних ресурсах",
    ),
    "respectRules": MessageLookupByLibrary.simpleMessage("Соблюдать правила"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS-соединения следуют правилам; необходимо настроить proxy-server-nameserver",
    ),
    "responseCode": MessageLookupByLibrary.simpleMessage("Код ответа"),
    "restart": MessageLookupByLibrary.simpleMessage("Перезапустить"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите перезапустить ядро?",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("Восстановить"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage(
      "Восстановить все данные",
    ),
    "restoreException": MessageLookupByLibrary.simpleMessage(
      "Ошибка восстановления",
    ),
    "restoreFromFileDesc": MessageLookupByLibrary.simpleMessage(
      "Восстановить данные из файла",
    ),
    "restoreFromWebDAVDesc": MessageLookupByLibrary.simpleMessage(
      "Восстановить данные из WebDAV",
    ),
    "restoreHiddenGroups": MessageLookupByLibrary.simpleMessage(
      "Снова скрывать группы",
    ),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage(
      "Восстановить только профили",
    ),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage(
      "Стратегия восстановления",
    ),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage(
      "Совместимость",
    ),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage(
      "Перезапись",
    ),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage(
      "Восстановление выполнено",
    ),
    "retry": MessageLookupByLibrary.simpleMessage("Повторить"),
    "role": MessageLookupByLibrary.simpleMessage("Роль"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("Адреса маршрутов"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage(
      "Настроить прослушиваемые адреса маршрутов",
    ),
    "routeMode": MessageLookupByLibrary.simpleMessage("Режим маршрутизации"),
    "routeModeBypassPrivate": MessageLookupByLibrary.simpleMessage(
      "Обходить частные адреса",
    ),
    "routeModeConfig": MessageLookupByLibrary.simpleMessage(
      "Использовать конфигурацию",
    ),
    "routes": MessageLookupByLibrary.simpleMessage("Маршруты"),
    "ru": MessageLookupByLibrary.simpleMessage("Русский"),
    "rule": MessageLookupByLibrary.simpleMessage("Правило"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage(
      "Логическое правило AND",
    ),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить полный домен",
    ),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить ключевое слово в домене",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по регулярному выражению домена",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить суффикс домена",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставление по маске; поддерживаются только * и ?",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить метку DSCP (только для входящих tproxy UDP)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон портов назначения",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить код страны IP-адреса",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить домены из Geosite",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить имя входящего подключения",
    ),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить входящий порт",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить тип входящего подключения",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить имя пользователя входящего подключения; несколько имён разделяются /",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить ASN, которой принадлежит IP",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон IP-адресов; IP-CIDR6 — просто псевдоним",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон IP-адресов",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон суффиксов IP",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставляет все запросы, условия не нужны",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить TCP или UDP",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage(
      "Логическое правило NOT",
    ),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage(
      "Логическое правило OR",
    ),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по имени процесса; на Android соответствует имени пакета",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по регулярному выражению имени процесса; на Android соответствует имени пакета",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по маске имени процесса; поддерживаются только * и ?",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по полному пути процесса",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по регулярному выражению пути процесса",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по маске пути процесса; поддерживаются только * и ?",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить имя повторного сопоставления; несколько имён разделяются /",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "Ссылка на набор правил; требуется настроить rule-providers",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить код страны IP источника",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить ASN IP источника",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон IP-адресов источника",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон суффиксов IP источника",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон портов источника",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "Переход к подправилу; обратите внимание на скобки",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить Linux USER ID",
    ),
    "ruleDisabled": MessageLookupByLibrary.simpleMessage("Отключено"),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("Правило пусто"),
    "ruleEnabled": MessageLookupByLibrary.simpleMessage("Включено"),
    "ruleHits": MessageLookupByLibrary.simpleMessage("Совпадения"),
    "ruleLastHit": MessageLookupByLibrary.simpleMessage("Последнее совпадение"),
    "ruleLastMiss": MessageLookupByLibrary.simpleMessage(
      "Последнее несовпадение",
    ),
    "ruleMisses": MessageLookupByLibrary.simpleMessage("Несовпадения"),
    "ruleName": MessageLookupByLibrary.simpleMessage("Название правила"),
    "ruleQueryDestinationIP": MessageLookupByLibrary.simpleMessage(
      "IP назначения",
    ),
    "ruleQueryInboundName": MessageLookupByLibrary.simpleMessage(
      "Имя входящего подключения",
    ),
    "ruleQueryInboundUser": MessageLookupByLibrary.simpleMessage(
      "Пользователь входящего подключения",
    ),
    "ruleQueryInvalidIP": MessageLookupByLibrary.simpleMessage(
      "Введите корректный IP-адрес.",
    ),
    "ruleQueryNoMatch": MessageLookupByLibrary.simpleMessage(
      "Нет совпадений (политика режима или DIRECT)",
    ),
    "ruleQueryNumberRange": m28,
    "ruleQueryPortInvalid": MessageLookupByLibrary.simpleMessage(
      "Введите порт от 1 до 65535.",
    ),
    "ruleQueryProcessPath": MessageLookupByLibrary.simpleMessage(
      "Путь процесса",
    ),
    "ruleQuerySniffHost": MessageLookupByLibrary.simpleMessage(
      "Обнаруженный домен",
    ),
    "ruleQuerySourcePort": MessageLookupByLibrary.simpleMessage(
      "Порт источника",
    ),
    "ruleQueryTarget": MessageLookupByLibrary.simpleMessage(
      "Домен или IP-адрес",
    ),
    "ruleSet": MessageLookupByLibrary.simpleMessage("Набор правил"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Цель правила"),
    "ruleType": MessageLookupByLibrary.simpleMessage("Тип правила"),
    "ruleUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось изменить правило. Возможно, конфигурация изменилась. Обновите список и повторите попытку.",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("Правила"),
    "rulesCount": m29,
    "rulesDesc": MessageLookupByLibrary.simpleMessage(
      "Просмотр правил и статистики совпадений",
    ),
    "save": MessageLookupByLibrary.simpleMessage("Сохранить"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("Сохранить изменения?"),
    "script": MessageLookupByLibrary.simpleMessage("Скрипт"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "Режим скрипта: использует внешние скрипты-расширения для переопределения конфигурации в один клик",
    ),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage(
      "Прокрутить к выбранному",
    ),
    "search": MessageLookupByLibrary.simpleMessage("Поиск"),
    "seconds": MessageLookupByLibrary.simpleMessage("секунд"),
    "secondsCount": m30,
    "selectAll": MessageLookupByLibrary.simpleMessage("Выбрать всё"),
    "selectMatchTarget": MessageLookupByLibrary.simpleMessage(
      "Выбрать MATCH-TARGET",
    ),
    "selectProxies": MessageLookupByLibrary.simpleMessage("Выбрать прокси"),
    "selectProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Выбрать провайдеров прокси",
    ),
    "selectRemoteBackup": MessageLookupByLibrary.simpleMessage(
      "Выберите резервную копию",
    ),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage(
      "Выберите набор правил",
    ),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "Выберите стратегию распределения",
    ),
    "selectSubRule": MessageLookupByLibrary.simpleMessage(
      "Выберите подправило",
    ),
    "selected": MessageLookupByLibrary.simpleMessage("Выбрано"),
    "selectedCountTitle": m31,
    "sendMsgX": MessageLookupByLibrary.simpleMessage("Включить SendMsgX"),
    "sendMsgXDesc": MessageLookupByLibrary.simpleMessage(
      "Пакетная отправка пакетов в Darwin",
    ),
    "server": MessageLookupByLibrary.simpleMessage("Сервер"),
    "settings": MessageLookupByLibrary.simpleMessage("Настройки"),
    "show": MessageLookupByLibrary.simpleMessage("Показать"),
    "showHiddenGroups": MessageLookupByLibrary.simpleMessage(
      "Показать скрытые группы",
    ),
    "showLess": MessageLookupByLibrary.simpleMessage("Свернуть"),
    "showMore": MessageLookupByLibrary.simpleMessage("Развернуть"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "Кнопка остановки в уведомлении",
    ),
    "showNotificationStopActionDesc": MessageLookupByLibrary.simpleMessage(
      "Показывать кнопку остановки в постоянном уведомлении. Отключите, если из-за неё система всегда разворачивает уведомление",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage("Показать пароль"),
    "showQuickSettingsProfileName": MessageLookupByLibrary.simpleMessage(
      "Показывать имя текущего профиля",
    ),
    "showQuickSettingsProfileNameDesc": MessageLookupByLibrary.simpleMessage(
      "Показывать имя профиля на быстром переключателе при подключении",
    ),
    "showTrayProxySelection": MessageLookupByLibrary.simpleMessage(
      "Показывать выбор прокси в трее",
    ),
    "showTrayProxySelectionDesc": MessageLookupByLibrary.simpleMessage(
      "Показывать группы и узлы прокси в меню трея для быстрого переключения",
    ),
    "showUnavailable": MessageLookupByLibrary.simpleMessage("Показать таймаут"),
    "shrink": MessageLookupByLibrary.simpleMessage("Компактный"),
    "signIn": MessageLookupByLibrary.simpleMessage("Войти"),
    "signOut": MessageLookupByLibrary.simpleMessage("Выйти"),
    "signedIn": MessageLookupByLibrary.simpleMessage("Вход выполнен"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("Тихий запуск"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Запускаться в фоновом режиме",
    ),
    "size": MessageLookupByLibrary.simpleMessage("Размер"),
    "small": MessageLookupByLibrary.simpleMessage("Мелкий"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Порт SOCKS"),
    "sort": MessageLookupByLibrary.simpleMessage("Сортировка"),
    "source": MessageLookupByLibrary.simpleMessage("Источник"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("IP источника"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("Специальный прокси"),
    "specialRules": MessageLookupByLibrary.simpleMessage("Специальные правила"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage(
      "Статистика скорости",
    ),
    "splitStrategy": MessageLookupByLibrary.simpleMessage(
      "Стратегия распределения",
    ),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Стратегия распределения не может быть пустой",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("Список SSID пуст"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Режим стека"),
    "standard": MessageLookupByLibrary.simpleMessage("Стандартный"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "Стандартный режим: переопределяет базовую конфигурацию и позволяет просто добавлять правила",
    ),
    "start": MessageLookupByLibrary.simpleMessage("Старт"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage("С нуля"),
    "startVpn": MessageLookupByLibrary.simpleMessage("Запуск VPN..."),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage(
      "Запуск и фоновая работа",
    ),
    "status": MessageLookupByLibrary.simpleMessage("Статус"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "При отключении используется системный DNS",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Стоп"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Остановка VPN..."),
    "stopped": MessageLookupByLibrary.simpleMessage("Остановлено"),
    "strictRoute": MessageLookupByLibrary.simpleMessage(
      "Строгая маршрутизация",
    ),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать строгий режим маршрутизации TUN",
    ),
    "style": MessageLookupByLibrary.simpleMessage("Стиль"),
    "styleSettings": MessageLookupByLibrary.simpleMessage("Настройки стиля"),
    "subRule": MessageLookupByLibrary.simpleMessage("Подправило"),
    "subRuleEmpty": MessageLookupByLibrary.simpleMessage("Подправило пусто"),
    "subRuleNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Подправило не может быть пустым",
    ),
    "submit": MessageLookupByLibrary.simpleMessage("Отправить"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "Информация о подписке",
    ),
    "suspendSupport": MessageLookupByLibrary.simpleMessage(
      "Поддержка приостановки",
    ),
    "suspendSupportDesc": MessageLookupByLibrary.simpleMessage(
      "Приостанавливать ядро при простое устройства, чтобы снизить расход батареи",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("Приостановлено..."),
    "swipeToSwitchPage": MessageLookupByLibrary.simpleMessage(
      "Переключение страниц свайпом",
    ),
    "sync": MessageLookupByLibrary.simpleMessage("Синхронизация"),
    "system": MessageLookupByLibrary.simpleMessage("Система"),
    "systemApp": MessageLookupByLibrary.simpleMessage("Системные приложения"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("Системный прокси"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Настроить системный HTTP-прокси",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("Вкладки"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("Анимация вкладок"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "Действует только в мобильном виде",
    ),
    "tailscaleActive": MessageLookupByLibrary.simpleMessage("Активен"),
    "tailscaleCurrentEndpoint": MessageLookupByLibrary.simpleMessage(
      "Текущая конечная точка",
    ),
    "tailscaleDnsName": MessageLookupByLibrary.simpleMessage("DNS-имя"),
    "tailscaleEndpoints": MessageLookupByLibrary.simpleMessage(
      "Конечные точки",
    ),
    "tailscaleExitNode": MessageLookupByLibrary.simpleMessage("Выходной узел"),
    "tailscaleExitNodeAvailable": MessageLookupByLibrary.simpleMessage(
      "Доступен как выходной узел",
    ),
    "tailscaleHealth": MessageLookupByLibrary.simpleMessage("Состояние"),
    "tailscaleHealthWarnings": MessageLookupByLibrary.simpleMessage(
      "Предупреждения о состоянии",
    ),
    "tailscaleKeyExpired": MessageLookupByLibrary.simpleMessage(
      "Срок действия ключа истёк",
    ),
    "tailscaleKeyExpiry": MessageLookupByLibrary.simpleMessage(
      "Срок действия ключа",
    ),
    "tailscaleLastHandshake": MessageLookupByLibrary.simpleMessage(
      "Последнее рукопожатие",
    ),
    "tailscaleLastSeen": MessageLookupByLibrary.simpleMessage(
      "Последняя активность",
    ),
    "tailscaleNeedsMachineAuth": MessageLookupByLibrary.simpleMessage(
      "Требуется одобрение устройства",
    ),
    "tailscaleNodeKey": MessageLookupByLibrary.simpleMessage("Ключ узла"),
    "tailscaleRelay": MessageLookupByLibrary.simpleMessage("Ретранслятор DERP"),
    "tailscaleSubnets": MessageLookupByLibrary.simpleMessage("Подсети"),
    "tailscaleTags": MessageLookupByLibrary.simpleMessage("Теги"),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage(
      "Нажмите, чтобы разрешить",
    ),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("Параллельный TCP"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "При включении разрешает параллельные TCP-подключения",
    ),
    "testInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал тестирования",
    ),
    "testUrl": MessageLookupByLibrary.simpleMessage("URL для теста"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage(
      "Тестировать при использовании",
    ),
    "textReplacement": MessageLookupByLibrary.simpleMessage(
      "Подстановка текста:",
    ),
    "textScale": MessageLookupByLibrary.simpleMessage("Масштаб текста"),
    "theme": MessageLookupByLibrary.simpleMessage("Тема"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Цвет темы"),
    "themeDesc": MessageLookupByLibrary.simpleMessage(
      "Тёмный режим и настройка цветов",
    ),
    "themeMode": MessageLookupByLibrary.simpleMessage("Режим темы"),
    "tight": MessageLookupByLibrary.simpleMessage("Плотный"),
    "time": MessageLookupByLibrary.simpleMessage("Время"),
    "timeout": MessageLookupByLibrary.simpleMessage("Тайм-аут"),
    "tip": MessageLookupByLibrary.simpleMessage("Подсказка"),
    "toggle": MessageLookupByLibrary.simpleMessage("Переключить"),
    "toggleLabel": MessageLookupByLibrary.simpleMessage("Переключить подписи"),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("Тональный акцент"),
    "tools": MessageLookupByLibrary.simpleMessage("Инструменты"),
    "torch": MessageLookupByLibrary.simpleMessage("Фонарик"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("Общий трафик"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Порт TProxy"),
    "trafficBoth": MessageLookupByLibrary.simpleMessage("Оба"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("Статистика трафика"),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "Работает только в режиме администратора",
    ),
    "tunDnsMode": MessageLookupByLibrary.simpleMessage("Режим системного DNS"),
    "tunDnsModeDisabled": MessageLookupByLibrary.simpleMessage("Отключено"),
    "tunDnsModeHijack": MessageLookupByLibrary.simpleMessage("Перехват"),
    "tunDnsModeNative": MessageLookupByLibrary.simpleMessage("Нативный"),
    "turnOff": MessageLookupByLibrary.simpleMessage("Выключить"),
    "turnOn": MessageLookupByLibrary.simpleMessage("Включить"),
    "tvMode": MessageLookupByLibrary.simpleMessage("Режим ТВ"),
    "tvModeDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать раскладку для пульта на этом устройстве",
    ),
    "uiUpdateIdleInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал обновления в бездействии",
    ),
    "uiUpdateIdleWhenUnfocused": MessageLookupByLibrary.simpleMessage(
      "Бездействие без фокуса",
    ),
    "uiUpdateIdleWhenUnfocusedDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать интервал бездействия, когда окно приложения теряет фокус",
    ),
    "uiUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал обновления информации UI",
    ),
    "uiUpdateIntervalDesc": m32,
    "uiUpdateIntervalIdleDisabledDesc": m33,
    "unauthorized": MessageLookupByLibrary.simpleMessage("Не разрешено"),
    "undo": MessageLookupByLibrary.simpleMessage("Отменить"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("Единая задержка"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "Убирает лишние задержки, например рукопожатие",
    ),
    "uninitialized": MessageLookupByLibrary.simpleMessage(
      "Не инициализировано",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("Неизвестно"),
    "unknownBackupVariable": MessageLookupByLibrary.simpleMessage(
      "Неизвестная переменная. Выберите одну из переменных ниже.",
    ),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage(
      "Неизвестная сетевая ошибка",
    ),
    "unmaximize": MessageLookupByLibrary.simpleMessage("Свернуть в окно"),
    "unnamed": MessageLookupByLibrary.simpleMessage("Без названия"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage("Открепить окно"),
    "update": MessageLookupByLibrary.simpleMessage("Обновить"),
    "updateChecksumMismatch": MessageLookupByLibrary.simpleMessage(
      "Загруженный файл не совпадает с опубликованной контрольной суммой и был удалён.",
    ),
    "updateDownloading": MessageLookupByLibrary.simpleMessage(
      "Загрузка обновления",
    ),
    "updateInstallFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось запустить установщик.",
    ),
    "updateInstallPermission": MessageLookupByLibrary.simpleMessage(
      "FlClash не получил разрешение на установку приложений, поэтому обновление не установлено.",
    ),
    "updateNotWritable": MessageLookupByLibrary.simpleMessage(
      "FlClash не может записывать в папку установки. Загрузите обновление вручную.",
    ),
    "updateNow": MessageLookupByLibrary.simpleMessage("Обновить сейчас"),
    "upload": MessageLookupByLibrary.simpleMessage("Отдача"),
    "uploadSpeed": MessageLookupByLibrary.simpleMessage("Скорость загрузки"),
    "uploadTraffic": MessageLookupByLibrary.simpleMessage("Исходящий трафик"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage("Получить профиль по URL"),
    "urlTip": m34,
    "useHosts": MessageLookupByLibrary.simpleMessage("Использовать hosts"),
    "useHostsDesc": MessageLookupByLibrary.simpleMessage(
      "Проверяет записи hosts из конфигурации перед запросом к вышестоящим DNS-серверам",
    ),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage(
      "Использовать системный hosts",
    ),
    "useSystemHostsDesc": MessageLookupByLibrary.simpleMessage(
      "Проверяет системный файл Hosts при разрешении доменных имен",
    ),
    "usedTraffic": MessageLookupByLibrary.simpleMessage(
      "Использованный трафик",
    ),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "value": MessageLookupByLibrary.simpleMessage("Значение"),
    "version": MessageLookupByLibrary.simpleMessage("Версия"),
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("Яркая"),
    "view": MessageLookupByLibrary.simpleMessage("Просмотр"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "Обнаружено изменение настроек VPN",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматически направляет весь системный трафик через VpnService",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage(
      "Изменения вступят в силу после перезапуска VPN",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "Настройка WebDAV",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage(
      "Режим белого списка",
    ),
    "writeToSystem": MessageLookupByLibrary.simpleMessage(
      "Записывать в систему",
    ),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "Также устанавливать системные часы",
    ),
    "yearsAgo": m35,
    "yes": MessageLookupByLibrary.simpleMessage("Да"),
    "zhCN": MessageLookupByLibrary.simpleMessage("Упрощённый китайский"),
    "zhTW": MessageLookupByLibrary.simpleMessage("Традиционный китайский"),
  };
}

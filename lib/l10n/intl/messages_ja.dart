// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ja locale. All the
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
  String get localeName => 'ja';

  static String m0(code) =>
      "Windows が FlClashCore.exe の実行を拒否しました（エラー ${code}）。スマート アプリ コントロールや AppLocker などのアプリ制御ポリシーは未署名のプログラムをブロックします。ポリシーで FlClash を許可するか、ポリシーを無効にしてから再試行してください。";

  static String m1(name) =>
      "アプリの起動が2回連続で完了しませんでした。クラッシュループを断ち切るため、プロファイル ${name} の選択を解除し、今回の自動セットアップをスキップしました。いつでも選択し直せます。";

  static String m2(url) => "${url} からプロファイルを作成しますか？";

  static String m3(count) => "${count} 日前";

  static String m4(label) => "選択された ${label} を削除してもよろしいですか？";

  static String m5(label) => "現在の ${label} を削除してもよろしいですか？";

  static String m6(label) => "${label} 詳細";

  static String m7(label) => "${label} は空欄にできません";

  static String m8(count) => "${count} 件";

  static String m9(label) => "現在の ${label} は既に存在しています";

  static String m10(name) => "${name} はすでに最新です";

  static String m11(name) => "${name} を更新しました";

  static String m12(name) => "${name}を更新中...";

  static String m13(count) => "${count} 時間前";

  static String m14(count) => "${count} 時間";

  static String m15(target) => "${target} は無効なポリシーです";

  static String m16(proxyName) => "${proxyName} は無効なプロキシです";

  static String m17(providerName) => "${providerName} は無効なプロキシプロバイダーです";

  static String m18(subRule) => "${subRule} は無効な SUB_RULE です";

  static String m19(appName) =>
      "1. システム設定 > プライバシーとセキュリティ を開きます\n2. 位置情報サービス を選択します\n3. 右側の一覧で ${appName} を見つけてチェックします\n\n設定が完了したらアプリに戻り、通常どおり使用してください。ご協力ありがとうございます。";

  static String m20(label, max) => "${label}は最大${max}文字です";

  static String m21(count) => "${count} 分前";

  static String m22(count) => "${count} ヶ月前";

  static String m23(label) => "まだ ${label} はありません";

  static String m24(label) => "${label} は数字でなければなりません";

  static String m25(label) => "${label} は 1024 から 49151 の間でなければなりません，0 は無効です";

  static String m26(count) => "プロキシ ${count} 件";

  static String m27(count) => "ルール ${count} 件";

  static String m28(count) => "${count} 秒";

  static String m29(count) => "${count} 件選択中";

  static String m30(interval, idleInterval) =>
      "${interval} · アイドル ${idleInterval}";

  static String m31(interval) => "${interval} · アイドル無効";

  static String m32(label) => "${label} は URL である必要があります";

  static String m33(count) => "${count} 年前";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("アプリについて"),
    "accessControl": MessageLookupByLibrary.simpleMessage("アクセス制御"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリのみ VPN を許可",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "プロキシを利用するアプリを設定します",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "アプリアクセス制御は無効です",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリを VPN から除外",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage("アクセス制御の設定"),
    "accessDenied": MessageLookupByLibrary.simpleMessage("アクセス拒否"),
    "account": MessageLookupByLibrary.simpleMessage("アカウント"),
    "action": MessageLookupByLibrary.simpleMessage("アクション"),
    "actionMode": MessageLookupByLibrary.simpleMessage("モード切替"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("システムプロキシ"),
    "actionStart": MessageLookupByLibrary.simpleMessage("開始/停止"),
    "actionTun": MessageLookupByLibrary.simpleMessage("TUN"),
    "actionView": MessageLookupByLibrary.simpleMessage("表示/非表示"),
    "add": MessageLookupByLibrary.simpleMessage("追加"),
    "addProfile": MessageLookupByLibrary.simpleMessage("プロファイルを追加"),
    "addProxies": MessageLookupByLibrary.simpleMessage("プロキシを追加"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループを追加"),
    "addProxyProviders": MessageLookupByLibrary.simpleMessage("プロキシプロバイダーを追加"),
    "addRule": MessageLookupByLibrary.simpleMessage("ルールを追加"),
    "addSsid": MessageLookupByLibrary.simpleMessage("SSID を追加"),
    "addWidget": MessageLookupByLibrary.simpleMessage("ウィジェットを追加"),
    "addedRules": MessageLookupByLibrary.simpleMessage("追加ルール"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage("追加パラメータ"),
    "address": MessageLookupByLibrary.simpleMessage("アドレス"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("WebDAV サーバーアドレス"),
    "addressTip": MessageLookupByLibrary.simpleMessage("有効な WebDAV アドレスを入力"),
    "advancedConfig": MessageLookupByLibrary.simpleMessage("詳細設定"),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage("多彩な設定項目を提供します"),
    "ageKeyGenerateTitle": MessageLookupByLibrary.simpleMessage("Age キー生成"),
    "ageKeyPairGeneratedSuccess": MessageLookupByLibrary.simpleMessage(
      "X25519 キーペアを生成しました。安全に保管してください",
    ),
    "agePrivateKeyLabel": MessageLookupByLibrary.simpleMessage("Age 秘密鍵"),
    "agePrivateKeyRequired": MessageLookupByLibrary.simpleMessage(
      "先に正しい Age 秘密鍵を入力してください",
    ),
    "agePublicKeyLabel": MessageLookupByLibrary.simpleMessage("Age 公開鍵"),
    "ageSecretKeyInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "有効な Age 秘密鍵を入力してください（AGE-SECRET-KEY-で始まる必要があります）",
    ),
    "ageSecretKeyOptional": MessageLookupByLibrary.simpleMessage("Age 秘密鍵（任意）"),
    "agree": MessageLookupByLibrary.simpleMessage("同意する"),
    "allData": MessageLookupByLibrary.simpleMessage("すべてのデータ"),
    "allowBypass": MessageLookupByLibrary.simpleMessage(
      "アプリが VPN をバイパスすることを許可",
    ),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "有効化すると一部アプリが VPN をバイパス",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("LAN を許可"),
    "allowLanAccess": MessageLookupByLibrary.simpleMessage("LAN アクセスを許可"),
    "allowLanAccessDesc": MessageLookupByLibrary.simpleMessage(
      "LAN から外部コントローラーへのアクセスを許可",
    ),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage("LAN 経由でのプロキシアクセスを許可"),
    "alwaysOn": MessageLookupByLibrary.simpleMessage("常時接続"),
    "alwaysOnDesc": MessageLookupByLibrary.simpleMessage(
      "あらゆるネットワーク環境でVPN接続を維持",
    ),
    "app": MessageLookupByLibrary.simpleMessage("アプリ"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage("アプリアクセス制御"),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage("システム DNS を追加"),
    "appendSystemDnsTip": MessageLookupByLibrary.simpleMessage(
      "設定にシステム DNS を強制的に追加します",
    ),
    "application": MessageLookupByLibrary.simpleMessage("アプリケーション"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage(
      "アプリケーション関連の設定を変更します",
    ),
    "ascending": MessageLookupByLibrary.simpleMessage("昇順"),
    "authorize": MessageLookupByLibrary.simpleMessage("許可"),
    "authorized": MessageLookupByLibrary.simpleMessage("許可済み"),
    "auto": MessageLookupByLibrary.simpleMessage("自動"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("更新の自動チェック"),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "アプリ起動時に更新を自動的にチェックします",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage("接続を自動的に閉じる"),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "ノードの切り替え後、接続を自動的に閉じます",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("自動起動"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage("システム起動時に自動的に起動します"),
    "autoRun": MessageLookupByLibrary.simpleMessage("自動実行"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage("アプリを開いたときに自動的に実行します"),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage("オートセットシステム DNS"),
    "autoSetSystemDnsDesc": MessageLookupByLibrary.simpleMessage(
      "予備の DNS サーバーをシステムに追加",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("自動更新"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage("自動更新間隔（分）"),
    "back": MessageLookupByLibrary.simpleMessage("戻る"),
    "backup": MessageLookupByLibrary.simpleMessage("バックアップ"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage("バックアップと復元"),
    "backupAndRestoreDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAV またはファイルを介してデータを同期する",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("バックアップが完了しました"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("基本設定"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage("基本設定をグローバルに変更します"),
    "basicInfo": MessageLookupByLibrary.simpleMessage("基本情報"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("基本ポリシー"),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "バックグラウンド動作を確保するため、このアプリのバッテリー最適化を無効にしてください。タップして設定へ移動します。",
    ),
    "batteryOptimizationStatusTip": MessageLookupByLibrary.simpleMessage(
      "システムの制限により、実行中は電池の最適化の状態を正しく取得できません",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("連携"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("ブラックリストモード"),
    "blockConnection": MessageLookupByLibrary.simpleMessage("接続をブロック"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("除外ドメイン"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "システムプロキシが有効な場合のみ適用されます",
    ),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "キャッシュが破損しています。クリアしますか？",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("キャンセル"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("すべて選択解除"),
    "captureDns": MessageLookupByLibrary.simpleMessage("システム DNS を引き継ぐ"),
    "captureDnsDesc": MessageLookupByLibrary.simpleMessage(
      "すべてのシステム DNS クエリを内部 DNS モジュールに転送",
    ),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "プロキシの切り替えに失敗したため、前回の選択に戻しました",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage("破壊的変更"),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("新機能"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage("不具合修正"),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage("パフォーマンス"),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("取り消し"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage("TLS証明書を検証"),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "信頼できない証明書を拒否します。無効にすると、サブスクリプションやバックアップが中間者攻撃にさらされます",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("更新を確認"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage("すでに最新バージョンです"),
    "clear": MessageLookupByLibrary.simpleMessage("クリア"),
    "clearData": MessageLookupByLibrary.simpleMessage("データを消去"),
    "clearSearch": MessageLookupByLibrary.simpleMessage("検索をクリア"),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("クリップボードへエクスポート"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("クリップボードからインポート"),
    "close": MessageLookupByLibrary.simpleMessage("閉じる"),
    "closeAll": MessageLookupByLibrary.simpleMessage("すべて切断"),
    "closeConnections": MessageLookupByLibrary.simpleMessage("接続を閉じる"),
    "closeConnectionsPrompt": MessageLookupByLibrary.simpleMessage(
      "以前のプロキシを使用している接続を切断しますか？",
    ),
    "collapse": MessageLookupByLibrary.simpleMessage("折りたたむ"),
    "collapseQuickSettingsPanel": MessageLookupByLibrary.simpleMessage(
      "クイック設定パネルを閉じる",
    ),
    "collapseQuickSettingsPanelDesc": MessageLookupByLibrary.simpleMessage(
      "FlClash タイルをタップした後にクイック設定パネルを閉じます",
    ),
    "color": MessageLookupByLibrary.simpleMessage("カラー"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("カラースキーム"),
    "columns": MessageLookupByLibrary.simpleMessage("列数"),
    "compatible": MessageLookupByLibrary.simpleMessage("互換モード"),
    "configDataDetected": MessageLookupByLibrary.simpleMessage(
      "設定内にデータが見つかりました",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("OK"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "すべてのデータを消去してもよろしいですか？",
    ),
    "confirmClearSelectedData": MessageLookupByLibrary.simpleMessage(
      "選択したデータを消去してもよろしいですか？",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "このプロキシグループを削除してもよろしいですか？",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "現在のウィンドウを閉じてもよろしいですか？",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "コアを強制クラッシュさせてもよろしいですか？",
    ),
    "confirmOverwriteTip": MessageLookupByLibrary.simpleMessage(
      "確定すると既存のデータを上書きします",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("接続済み"),
    "connecting": MessageLookupByLibrary.simpleMessage("接続中"),
    "connection": MessageLookupByLibrary.simpleMessage("接続"),
    "connectionInfo": MessageLookupByLibrary.simpleMessage("接続数"),
    "connections": MessageLookupByLibrary.simpleMessage("接続"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage("現在の接続データを表示します"),
    "connectivity": MessageLookupByLibrary.simpleMessage("接続状態："),
    "content": MessageLookupByLibrary.simpleMessage("内容"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage("内容は空にできません"),
    "contentScheme": MessageLookupByLibrary.simpleMessage("コンテンツ"),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "グローバル追加ルールを管理",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("コピー"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage("環境変数をコピー"),
    "copyLink": MessageLookupByLibrary.simpleMessage("リンクをコピー"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("コピーしました"),
    "core": MessageLookupByLibrary.simpleMessage("コア"),
    "coreBlockedByPolicyTip": m0,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "Windows のスマート アプリ コントロールが、署名されていない FlClashCore.exe をブロックしました。Windows セキュリティ → アプリとブラウザーの制御 → スマート アプリ コントロールの設定で「オフ」を選び、FlClash を再起動してください。一度オフにすると、Windows を再インストールしない限り再度オンにはできません。",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("コアの状態"),
    "country": MessageLookupByLibrary.simpleMessage("地域"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("クラッシュを検出しました"),
    "crashDetectedTip": m1,
    "crashTest": MessageLookupByLibrary.simpleMessage("クラッシュテスト"),
    "create": MessageLookupByLibrary.simpleMessage("作成"),
    "createProfile": MessageLookupByLibrary.simpleMessage("プロファイルを作成"),
    "createProfileFromUrlTip": m2,
    "creationTime": MessageLookupByLibrary.simpleMessage("作成日時"),
    "custom": MessageLookupByLibrary.simpleMessage("カスタム"),
    "cut": MessageLookupByLibrary.simpleMessage("切り取り"),
    "dark": MessageLookupByLibrary.simpleMessage("ダーク"),
    "dashboard": MessageLookupByLibrary.simpleMessage("ダッシュボード"),
    "dataChangedSave": MessageLookupByLibrary.simpleMessage(
      "データの変更を検出しました。保存しますか？",
    ),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "変更の保存に失敗したため、元に戻しました",
    ),
    "daysAgo": m3,
    "defaultNameserver": MessageLookupByLibrary.simpleMessage("デフォルトネームサーバー"),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "DNS サーバーの解決用",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("デフォルト"),
    "delay": MessageLookupByLibrary.simpleMessage("遅延"),
    "delayTest": MessageLookupByLibrary.simpleMessage("遅延テスト"),
    "delete": MessageLookupByLibrary.simpleMessage("削除"),
    "deleteMultipTip": m4,
    "deleteTip": m5,
    "desc": MessageLookupByLibrary.simpleMessage(
      "mihomo ベースのマルチプラットフォームプロキシクライアント。シンプルで使いやすく、オープンソースで広告なし。",
    ),
    "descending": MessageLookupByLibrary.simpleMessage("降順"),
    "destination": MessageLookupByLibrary.simpleMessage("宛先"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage("宛先GeoIP"),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage("宛先 IP ASN"),
    "details": m6,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "サードパーティ API に依存（参考値）",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("開発者モード"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "開発者モードが有効になりました。",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("ダイレクト"),
    "disableUDP": MessageLookupByLibrary.simpleMessage("UDP を無効化"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("免責事項"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェアは、学習・交流や研究などの非商用目的でのみ使用できます。商用目的での使用は固く禁じられています。いかなる商業行為も本ソフトウェアとは一切関係ありません。",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("切断済み"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "新しいバージョンが見つかりました",
    ),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("DNS 関連設定の更新"),
    "dnsHijack": MessageLookupByLibrary.simpleMessage("DNS ハイジャック"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "DNS クエリを内部 DNS モジュールに転送",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("DNSハイジャック"),
    "dnsIPv6Desc": MessageLookupByLibrary.simpleMessage(
      "無効にすると、AAAA クエリは空の結果を返します",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNS モード"),
    "domain": MessageLookupByLibrary.simpleMessage("ドメイン"),
    "download": MessageLookupByLibrary.simpleMessage("ダウンロード"),
    "downloadSpeed": MessageLookupByLibrary.simpleMessage("ダウンロード速度"),
    "downloadTraffic": MessageLookupByLibrary.simpleMessage("ダウンロード通信量"),
    "edit": MessageLookupByLibrary.simpleMessage("編集"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage("グローバルルールを編集"),
    "editProxy": MessageLookupByLibrary.simpleMessage("プロキシを編集"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループを編集"),
    "editRule": MessageLookupByLibrary.simpleMessage("ルールを編集"),
    "editSsid": MessageLookupByLibrary.simpleMessage("SSID を編集"),
    "emptyTip": m7,
    "en": MessageLookupByLibrary.simpleMessage("英語"),
    "enableExternalController": MessageLookupByLibrary.simpleMessage(
      "外部コントローラーを有効にする",
    ),
    "endpointIndependentNat": MessageLookupByLibrary.simpleMessage("NAT 強化"),
    "endpointIndependentNatDesc": MessageLookupByLibrary.simpleMessage(
      "UDP および P2P アプリの接続を最適化",
    ),
    "endpoints": MessageLookupByLibrary.simpleMessage("エンドポイント"),
    "enforceRoutes": MessageLookupByLibrary.simpleMessage("ルートを強制"),
    "enforceRoutesDesc": MessageLookupByLibrary.simpleMessage(
      "より具体的なルートが存在してもトラフィックをトンネル経由にする",
    ),
    "entries": MessageLookupByLibrary.simpleMessage(" 件"),
    "entriesCount": m8,
    "exclude": MessageLookupByLibrary.simpleMessage("最近のタスクから隠す"),
    "excludeAPNs": MessageLookupByLibrary.simpleMessage("APNs を除外"),
    "excludeAPNsDesc": MessageLookupByLibrary.simpleMessage(
      "Apple プッシュ通知トラフィックがトンネルをバイパスすることを許可する",
    ),
    "excludeCellularServices": MessageLookupByLibrary.simpleMessage(
      "セルラーサービスを除外",
    ),
    "excludeCellularServicesDesc": MessageLookupByLibrary.simpleMessage(
      "Wi-Fi 通話などのセルラーサービストラフィックがトンネルをバイパスすることを許可する",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "バックグラウンド時に、最近のタスクからアプリを隠します",
    ),
    "excludeDeviceCommunication": MessageLookupByLibrary.simpleMessage(
      "デバイス間通信を除外",
    ),
    "excludeDeviceCommunicationDesc": MessageLookupByLibrary.simpleMessage(
      "AirDrop や AirPlay などのデバイス間通信がトンネルをバイパスすることを許可する",
    ),
    "excludeLocalNetworks": MessageLookupByLibrary.simpleMessage(
      "ローカルネットワークを除外",
    ),
    "excludeLocalNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "ローカルネットワーク上のデバイスへの直接アクセスを許可する",
    ),
    "excludeProxyFilter": MessageLookupByLibrary.simpleMessage("除外ノードフィルター"),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("除外 SSID"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "除外した SSID の Wi-Fi に接続すると、アプリの実行状態が自動的に切り替わります。",
    ),
    "excludeType": MessageLookupByLibrary.simpleMessage("除外タイプ"),
    "existsTip": m9,
    "exit": MessageLookupByLibrary.simpleMessage("終了"),
    "expand": MessageLookupByLibrary.simpleMessage("展開"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("期待するステータス"),
    "expireTime": MessageLookupByLibrary.simpleMessage("有効期限"),
    "exportFile": MessageLookupByLibrary.simpleMessage("ファイルをエクスポート"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("ログをエクスポート"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("エクスポートが完了しました"),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("エクスプレッシブ"),
    "externalController": MessageLookupByLibrary.simpleMessage("外部コントローラー"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Clash コアへの外部アクセスを設定",
    ),
    "externalFetch": MessageLookupByLibrary.simpleMessage("外部取得"),
    "externalLink": MessageLookupByLibrary.simpleMessage("外部リンク"),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("FakeIP フィルター"),
    "fakeipFilterDesc": MessageLookupByLibrary.simpleMessage(
      "Fake IP モードで一致したドメインには Fake IP ではなく実 IP を返します",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("FakeIP 範囲"),
    "fallback": MessageLookupByLibrary.simpleMessage("フォールバック"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage("通常は海外 DNS を使用"),
    "fallbackDomainDesc": MessageLookupByLibrary.simpleMessage(
      "一致するドメインは nameserver へ問い合わせず、直接 fallback を使用します",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("フォールバックフィルター"),
    "fallbackGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "nameserver の結果を GeoIP コードで確認し、その地域外なら fallback を使用します",
    ),
    "fallbackGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "これらの GeoSite カテゴリに一致するドメインは直接 fallback を使用します",
    ),
    "fallbackIpcidrDesc": MessageLookupByLibrary.simpleMessage(
      "nameserver の結果がこれらの CIDR プレフィックスに一致すると fallback の結果へ切り替えます",
    ),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("フィデリティ"),
    "file": MessageLookupByLibrary.simpleMessage("ファイル"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("プロファイルファイルを直接アップロードします"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "ファイルが変更されています。変更を保存しますか？",
    ),
    "filter": MessageLookupByLibrary.simpleMessage("フィルター"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("プロセス検出"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "有効にすると、パフォーマンスが多少低下します",
    ),
    "followProfile": MessageLookupByLibrary.simpleMessage("プロファイルに従う"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("フォント"),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "コアを強制再起動してもよろしいですか？",
    ),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("フルーツサラダ"),
    "general": MessageLookupByLibrary.simpleMessage("一般"),
    "generateFromPrivateKey": MessageLookupByLibrary.simpleMessage(
      "Age 秘密鍵から生成",
    ),
    "generateSecret": MessageLookupByLibrary.simpleMessage("生成"),
    "geoAutoUpdate": MessageLookupByLibrary.simpleMessage("自動更新"),
    "geoAutoUpdateInterval": MessageLookupByLibrary.simpleMessage("自動更新間隔"),
    "geoAutoUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "自動更新間隔は0より大きくしてください",
    ),
    "geoOptions": MessageLookupByLibrary.simpleMessage("Geoオプション"),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geoリソース"),
    "geoSkipped": m10,
    "geoUpdated": m11,
    "geoUpdating": m12,
    "geodataLoader": MessageLookupByLibrary.simpleMessage("Geo 低メモリモード"),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "有効化すると Geo 低メモリローダーを使用",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("GeoIP コード"),
    "geositeMatcher": MessageLookupByLibrary.simpleMessage("高性能 Geo マッチャー"),
    "geositeMatcherDesc": MessageLookupByLibrary.simpleMessage(
      "有効化すると最小完全ハッシュアルゴリズムで照合",
    ),
    "global": MessageLookupByLibrary.simpleMessage("グローバル"),
    "go": MessageLookupByLibrary.simpleMessage("開く"),
    "goDownload": MessageLookupByLibrary.simpleMessage("ダウンロードへ"),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage("スクリプト設定へ移動"),
    "goroutineInfo": MessageLookupByLibrary.simpleMessage("ゴルーチン数"),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage("変更をキャッシュしますか？"),
    "header": MessageLookupByLibrary.simpleMessage("ヘッダー"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Helper サービスが利用できないため、TUN モードを有効にできません。FlClash を再インストールしてください。",
    ),
    "hide": MessageLookupByLibrary.simpleMessage("非表示"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("リストから隠す"),
    "hidePassword": MessageLookupByLibrary.simpleMessage("パスワードを隠す"),
    "hideUnavailable": MessageLookupByLibrary.simpleMessage("タイムアウト非表示"),
    "highPriorityAutoLaunch": MessageLookupByLibrary.simpleMessage("高優先度自動起動"),
    "highPriorityAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Windows タスクスケジューラでより早く起動します",
    ),
    "host": MessageLookupByLibrary.simpleMessage("ホスト"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("Hostsを追加します"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("ホットキーが競合しています"),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("ホットキー管理"),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "キーボードでアプリを操作します",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("時間"),
    "hoursAgo": m13,
    "hoursCount": m14,
    "icmpForwarding": MessageLookupByLibrary.simpleMessage("ICMP 転送"),
    "icmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "有効化すると ICMP Ping をサポート",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("アイコン"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("アイコン履歴"),
    "iconSource": MessageLookupByLibrary.simpleMessage("アイコンソース"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("アイコンスタイル"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("アイコン URL"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "バッテリー最適化を無視",
    ),
    "ignoreCertificateErrors": MessageLookupByLibrary.simpleMessage(
      "証明書の検証を無視",
    ),
    "ignoreCertificateErrorsDesc": MessageLookupByLibrary.simpleMessage(
      "無効な証明書を使用する HTTPS 接続を許可します。セキュリティが低下します",
    ),
    "import": MessageLookupByLibrary.simpleMessage("インポート"),
    "importFile": MessageLookupByLibrary.simpleMessage("ファイルからインポート"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("URL からインポート"),
    "importUrl": MessageLookupByLibrary.simpleMessage("URL からインポート"),
    "includeAllNetworks": MessageLookupByLibrary.simpleMessage("すべてのネットワークを含む"),
    "includeAllNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "ローカルおよびセルラーサービスを含むすべてのネットワークトラフィックをトンネル経由にする",
    ),
    "includeAllProxies": MessageLookupByLibrary.simpleMessage("すべてのプロキシを含める"),
    "includeAllProxiesTip": MessageLookupByLibrary.simpleMessage(
      "プロキシグループに属さないすべてのプロキシを取り込みます。下でプロキシグループを追加できます",
    ),
    "includeAllProxyProviders": MessageLookupByLibrary.simpleMessage(
      "すべてのプロキシプロバイダーを含める",
    ),
    "includeAllProxyProvidersTip": MessageLookupByLibrary.simpleMessage(
      "有効にすると、取り込んだプロキシプロバイダーを上書きします",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("無期限"),
    "init": MessageLookupByLibrary.simpleMessage("初期化"),
    "initialize": MessageLookupByLibrary.simpleMessage("初期化"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "正しいホットキーを入力してください",
    ),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "プロキシグループ名を入力してください",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage("ルールの内容を入力してください"),
    "installedAppsPermissionDeniedMessage":
        MessageLookupByLibrary.simpleMessage(
          "アプリ一覧の権限が拒否されたため、インストール済みアプリを取得できません。システム設定から手動で許可してください。",
        ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "このシステムでは、許可するまでインストール済みアプリの一覧が提供されません。許可すると、アプリごとのプロキシを設定できます。",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "アプリ一覧の権限が必要です",
    ),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("スマート選択"),
    "interfaceName": MessageLookupByLibrary.simpleMessage("インターフェース名"),
    "interfaceNameDesc": MessageLookupByLibrary.simpleMessage(
      "アウトバウンド接続に使用するネットワークインターフェース名",
    ),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage(
      "アウトバウンドインターフェース",
    ),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("クリア"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage("カスタム"),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage("設定に従う"),
    "internet": MessageLookupByLibrary.simpleMessage("インターネット"),
    "interval": MessageLookupByLibrary.simpleMessage("間隔"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("イントラネット IP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage("無効なバックアップファイル"),
    "invalidPolicy": m15,
    "invalidProxy": m16,
    "invalidProxyProvider": m17,
    "invalidSubRule": m18,
    "ipcidr": MessageLookupByLibrary.simpleMessage("IP/CIDR"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage("有効化すると IPv6 トラフィックを受信可能"),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage("IPv6 インバウンドを許可"),
    "ja": MessageLookupByLibrary.simpleMessage("日本語"),
    "justNow": MessageLookupByLibrary.simpleMessage("たった今"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "TCP キープアライブ間隔",
    ),
    "key": MessageLookupByLibrary.simpleMessage("キー"),
    "language": MessageLookupByLibrary.simpleMessage("言語"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage("起動が完了しませんでした"),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "前回、アプリは起動中に予期せず終了しました。今回の自動セットアップはスキップしました。手動で起動して再試行できます。",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("レイアウト"),
    "level": MessageLookupByLibrary.simpleMessage("レベル"),
    "light": MessageLookupByLibrary.simpleMessage("ライト"),
    "list": MessageLookupByLibrary.simpleMessage("リスト"),
    "listen": MessageLookupByLibrary.simpleMessage("リッスン"),
    "listeningPort": MessageLookupByLibrary.simpleMessage("リスニングポート"),
    "loading": MessageLookupByLibrary.simpleMessage("読み込み中..."),
    "local": MessageLookupByLibrary.simpleMessage("ローカル"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "ローカルにデータをバックアップします",
    ),
    "locationPermission": MessageLookupByLibrary.simpleMessage("位置情報の権限"),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "位置情報の権限が拒否されたため、現在の Wi-Fi 名を取得できません。システム設定で位置情報の権限を手動で有効にしてください。",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "システムの要件により、Wi-Fi 名の取得には位置情報の権限が必要です。Android では「常に許可」を選択してください。そうしないと、アプリがバックグラウンドにあるときに Wi-Fi 名を取得できません。",
    ),
    "locationPermissionGuide": m19,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "位置情報の権限が必要です",
    ),
    "log": MessageLookupByLibrary.simpleMessage("ログ"),
    "logLevel": MessageLookupByLibrary.simpleMessage("ログレベル"),
    "logcat": MessageLookupByLibrary.simpleMessage("ログキャプチャ"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage("無効にするとログの入り口が非表示になります"),
    "logs": MessageLookupByLibrary.simpleMessage("ログ"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("キャプチャしたログの記録"),
    "logsTest": MessageLookupByLibrary.simpleMessage("ログテスト"),
    "loopback": MessageLookupByLibrary.simpleMessage("ループバック解除ツール"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage("UWP ループバック解除用"),
    "loose": MessageLookupByLibrary.simpleMessage("ゆったり"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage("送信元 IP をマッチング"),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "matchTargetDesc": MessageLookupByLibrary.simpleMessage(
      "MATCH-TARGET を対象にしたルールの行き先。既定ではこのプロファイル末尾の MATCH ルールのターゲットを使います。",
    ),
    "matchTargetTitle": MessageLookupByLibrary.simpleMessage("マッチ先"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("最大失敗回数"),
    "maxLengthTip": m20,
    "maximize": MessageLookupByLibrary.simpleMessage("最大化"),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("メモリ情報"),
    "messageTest": MessageLookupByLibrary.simpleMessage("メッセージテスト"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("これはメッセージです。"),
    "min": MessageLookupByLibrary.simpleMessage("最小"),
    "minimize": MessageLookupByLibrary.simpleMessage("最小化"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("終了時に最小化"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "システム標準の終了動作を変更します",
    ),
    "minutesAgo": m21,
    "mixedPort": MessageLookupByLibrary.simpleMessage("Mixedポート"),
    "mode": MessageLookupByLibrary.simpleMessage("モード"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("モノクローム"),
    "monochromeTrayIcon": MessageLookupByLibrary.simpleMessage("モノクロのトレイアイコン"),
    "monthsAgo": m22,
    "more": MessageLookupByLibrary.simpleMessage("その他"),
    "mtu": MessageLookupByLibrary.simpleMessage("MTU"),
    "mtuRangeTip": MessageLookupByLibrary.simpleMessage(
      "MTU は 1 から 65535 までの整数である必要があります",
    ),
    "multipleValuesTip": MessageLookupByLibrary.simpleMessage(
      "複数の値はカンマで区切ってください",
    ),
    "name": MessageLookupByLibrary.simpleMessage("名前"),
    "nameserver": MessageLookupByLibrary.simpleMessage("ネームサーバー"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage("ドメインの名前解決に使用します"),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage("ネームサーバーポリシー"),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "一致するドメイン、GeoSite カテゴリ、またはルールセットに DNS サーバーを割り当てます",
    ),
    "needsLogin": MessageLookupByLibrary.simpleMessage("サインインが必要"),
    "network": MessageLookupByLibrary.simpleMessage("ネットワーク"),
    "networkDesc": MessageLookupByLibrary.simpleMessage("ネットワーク関連の設定を変更します"),
    "networkDetection": MessageLookupByLibrary.simpleMessage("ネットワーク検出"),
    "networkException": MessageLookupByLibrary.simpleMessage(
      "ネットワークエラーです。接続を確認してから再試行してください",
    ),
    "networkExtension": MessageLookupByLibrary.simpleMessage("ネットワーク拡張"),
    "networkId": MessageLookupByLibrary.simpleMessage("ネットワーク ID"),
    "networkNotFound": MessageLookupByLibrary.simpleMessage("ネットワークが見つかりません"),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("ネットワーク速度"),
    "networkSpeedNotification": MessageLookupByLibrary.simpleMessage(
      "リアルタイムのネットワーク速度を表示",
    ),
    "networkSpeedNotificationDesc": MessageLookupByLibrary.simpleMessage(
      "システムのステータス領域にリアルタイムのネットワーク速度を表示します。消費電力がわずかに増える場合があります",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("ネットワーク種別"),
    "networking": MessageLookupByLibrary.simpleMessage("メッシュネットワーク"),
    "networkingDesc": MessageLookupByLibrary.simpleMessage("P2P ネットワークの状態を表示"),
    "networkingNoOutbounds": MessageLookupByLibrary.simpleMessage(
      "現在の設定に P2P アウトバウンドはありません",
    ),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("ニュートラル"),
    "nextMatch": MessageLookupByLibrary.simpleMessage("次の一致"),
    "noData": MessageLookupByLibrary.simpleMessage("データがありません"),
    "noFilterCondition": MessageLookupByLibrary.simpleMessage("フィルター条件なし"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("ホットキーはまだありません"),
    "noInfo": MessageLookupByLibrary.simpleMessage("情報がありません"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage("今後表示しない"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("ネットワークがありません"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("ネットワーク不使用アプリ"),
    "noRecords": MessageLookupByLibrary.simpleMessage("記録がありません"),
    "noResolve": MessageLookupByLibrary.simpleMessage("IP を解決しない"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage("ホスト名を解決しない"),
    "nodes": MessageLookupByLibrary.simpleMessage("ノード"),
    "none": MessageLookupByLibrary.simpleMessage("なし"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "現在のプロキシグループは選択できません",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイルがありません。先にプロファイルを追加してください",
    ),
    "nullTip": m23,
    "numberTip": m24,
    "offline": MessageLookupByLibrary.simpleMessage("オフライン"),
    "onDemand": MessageLookupByLibrary.simpleMessage("オンデマンド"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "特定のシナリオでのアプリの実行状態を設定",
    ),
    "online": MessageLookupByLibrary.simpleMessage("オンライン"),
    "onlyConfig": MessageLookupByLibrary.simpleMessage("設定のみ"),
    "onlyEmoji": MessageLookupByLibrary.simpleMessage("Emoji のみ"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("アイコンのみ"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage("プロキシのみ集計"),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "有効にすると、プロキシのトラフィックのみを集計します",
    ),
    "optional": MessageLookupByLibrary.simpleMessage("任意"),
    "options": MessageLookupByLibrary.simpleMessage("オプション"),
    "other": MessageLookupByLibrary.simpleMessage("その他"),
    "otherContributors": MessageLookupByLibrary.simpleMessage("その他の貢献者"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("アウトバウンドモード"),
    "override": MessageLookupByLibrary.simpleMessage("上書き"),
    "overrideDns": MessageLookupByLibrary.simpleMessage("DNS 上書き"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとプロファイルの DNS 設定を上書き",
    ),
    "overrideMode": MessageLookupByLibrary.simpleMessage("上書きモード"),
    "overrideScript": MessageLookupByLibrary.simpleMessage("上書きスクリプト"),
    "overwriteTypeCustom": MessageLookupByLibrary.simpleMessage("カスタム"),
    "overwriteTypeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "カスタムモード：プロキシグループとルールを完全にカスタマイズできます",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("パレット"),
    "password": MessageLookupByLibrary.simpleMessage("パスワード"),
    "paste": MessageLookupByLibrary.simpleMessage("貼り付け"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage("アルバムから選択"),
    "pinWindow": MessageLookupByLibrary.simpleMessage("最前面に固定"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "WebDAV をバインドしてください",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "スクリプト名を入力してください",
    ),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "管理者パスワードを入力してください",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "有効な QR コードをアップロードしてください",
    ),
    "port": MessageLookupByLibrary.simpleMessage("ポート"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage("別のポートを入力してください"),
    "portTip": m25,
    "positiveIntegerTip": MessageLookupByLibrary.simpleMessage(
      "0 より大きい整数を入力してください",
    ),
    "predictiveBack": MessageLookupByLibrary.simpleMessage("予測型戻る"),
    "preferH3": MessageLookupByLibrary.simpleMessage("HTTP/3 を優先"),
    "preferH3Desc": MessageLookupByLibrary.simpleMessage("DoH の HTTP/3 を優先します"),
    "prerequisites": MessageLookupByLibrary.simpleMessage("前提条件"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("キーを押してください"),
    "preview": MessageLookupByLibrary.simpleMessage("プレビュー"),
    "previousMatch": MessageLookupByLibrary.simpleMessage("前の一致"),
    "process": MessageLookupByLibrary.simpleMessage("プロセス"),
    "profile": MessageLookupByLibrary.simpleMessage("プロファイル"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("有効な間隔を入力してください"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("自動更新間隔を入力してください"),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "プロファイルが変更されています。自動更新を無効にしますか？",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイル名を入力してください",
    ),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "有効なプロファイル URL を入力してください",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイル URL を入力してください",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("プロファイル"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("プロファイルの並べ替え"),
    "project": MessageLookupByLibrary.simpleMessage("プロジェクト"),
    "promptCloseConnections": MessageLookupByLibrary.simpleMessage("接続終了の確認"),
    "promptCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "ノード変更後に接続を切断するか確認します",
    ),
    "providers": MessageLookupByLibrary.simpleMessage("外部リソース"),
    "proxies": MessageLookupByLibrary.simpleMessage("プロキシ"),
    "proxiesCount": m26,
    "proxiesEmpty": MessageLookupByLibrary.simpleMessage("プロキシが空です"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("プロキシチェーン"),
    "proxyDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "選択したプロキシに異常が見つかりました",
    ),
    "proxyFilter": MessageLookupByLibrary.simpleMessage("ノードフィルター"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループ"),
    "proxyGroupDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "現在のプロキシグループに異常が見つかりました",
    ),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage("プロキシグループが空です"),
    "proxyGroupNameDuplicate": MessageLookupByLibrary.simpleMessage(
      "プロキシグループ名が重複しています",
    ),
    "proxyGroupNameEmpty": MessageLookupByLibrary.simpleMessage(
      "プロキシグループ名は空にできません",
    ),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("プロキシネームサーバー"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "プロキシノードのドメイン解決用",
    ),
    "proxyNameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "プロキシネームサーバーポリシー",
    ),
    "proxyNameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "プロキシノードのネームサーバーポリシーを指定",
    ),
    "proxyProviderDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "選択したプロキシプロバイダーに異常が見つかりました",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("プロキシプロバイダー"),
    "proxyProvidersEmpty": MessageLookupByLibrary.simpleMessage(
      "プロキシプロバイダーが空です",
    ),
    "proxyProvidersNotEmpty": MessageLookupByLibrary.simpleMessage(
      "プロキシプロバイダーは空にできません",
    ),
    "proxyType": MessageLookupByLibrary.simpleMessage("プロキシタイプ"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("キャッシュを整理"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("ピュアブラックモード"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR コード"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "QR コードをスキャンしてプロファイルを取得",
    ),
    "quickFill": MessageLookupByLibrary.simpleMessage("クイック入力"),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("レインボー"),
    "random": MessageLookupByLibrary.simpleMessage("ランダム"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir ポート"),
    "redo": MessageLookupByLibrary.simpleMessage("やり直す"),
    "regexSearch": MessageLookupByLibrary.simpleMessage("正規表現検索"),
    "relayed": MessageLookupByLibrary.simpleMessage("リレー"),
    "remote": MessageLookupByLibrary.simpleMessage("リモート"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAV にデータをバックアップ",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage("リモート宛先"),
    "remove": MessageLookupByLibrary.simpleMessage("削除"),
    "request": MessageLookupByLibrary.simpleMessage("リクエスト"),
    "requests": MessageLookupByLibrary.simpleMessage("リクエスト"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage("最近のリクエスト記録を表示します"),
    "reset": MessageLookupByLibrary.simpleMessage("リセット"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "このページには変更があります。リセットしてもよろしいですか？",
    ),
    "resetProfilesAndScripts": MessageLookupByLibrary.simpleMessage(
      "プロファイルとスクリプト",
    ),
    "resetSettingsData": MessageLookupByLibrary.simpleMessage("アプリ設定"),
    "resetTip": MessageLookupByLibrary.simpleMessage("リセットしてもよろしいですか？"),
    "resources": MessageLookupByLibrary.simpleMessage("リソース"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage("外部リソースの関連情報"),
    "respectRules": MessageLookupByLibrary.simpleMessage("ルールに従う"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS 接続をルールに従わせます（proxy-server-nameserver の設定が必要）",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("再起動"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage("コアを再起動してもよろしいですか？"),
    "restore": MessageLookupByLibrary.simpleMessage("復元"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage("すべてのデータを復元"),
    "restoreException": MessageLookupByLibrary.simpleMessage("復元エラー"),
    "restoreFromFileDesc": MessageLookupByLibrary.simpleMessage(
      "ファイルからデータを復元します",
    ),
    "restoreFromWebDAVDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAV を介してデータを復元する",
    ),
    "restoreHiddenGroups": MessageLookupByLibrary.simpleMessage("グループを再び非表示"),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage("プロファイルのみ復元"),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage("復元方式"),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage("互換"),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage("上書き"),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage("復元が完了しました"),
    "role": MessageLookupByLibrary.simpleMessage("ロール"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("ルートアドレス"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage(
      "リッスンするルートアドレスを設定します",
    ),
    "routeMode": MessageLookupByLibrary.simpleMessage("ルートモード"),
    "routeModeBypassPrivate": MessageLookupByLibrary.simpleMessage(
      "プライベートアドレスをバイパス",
    ),
    "routeModeConfig": MessageLookupByLibrary.simpleMessage("設定を使用"),
    "routes": MessageLookupByLibrary.simpleMessage("ルート"),
    "ru": MessageLookupByLibrary.simpleMessage("ロシア語"),
    "rule": MessageLookupByLibrary.simpleMessage("ルール"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage("論理ルール AND"),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage("完全なドメインにマッチ"),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "ドメインキーワードにマッチ",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "ワイルドカードでマッチ（* と ? のみ対応）",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "ドメインサフィックスにマッチ",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "DSCP マークをマッチング (tproxy udp inbound のみ)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "宛先ポート範囲にマッチ",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "IP の国コードをマッチング",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "GeoSite 内のドメインをマッチング",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage("インバウンド名にマッチ"),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンドポートにマッチ",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンドタイプにマッチ",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンドユーザー名にマッチ（/ で複数指定可）",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "IP の ASN をマッチング",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "IP アドレス範囲をマッチング（IP-CIDR6 はエイリアスです）",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "IP アドレス範囲をマッチング",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "IP 接尾辞範囲をマッチング",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "すべてのリクエストにマッチ（条件不要）",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "TCP または UDP をマッチング",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage("論理ルール NOT"),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("論理ルール OR"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "プロセス名でマッチング（Android ではパッケージ名）",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "プロセス名正規表現でマッチング（Android ではパッケージ名）",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "プロセスのフルパスでマッチ",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "プロセスパスの正規表現でマッチ",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "ルールセットを参照。rule-providers の設定が必要",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "送信元 IP の国コードをマッチング",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "送信元 IP の ASN をマッチング",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "送信元 IP アドレス範囲をマッチング",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "送信元 IP 接尾辞範囲をマッチング",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "送信元ポート範囲にマッチ",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "サブルールへマッチします。括弧の使い方に注意してください",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Linux USER ID をマッチング",
    ),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("ルールが空です"),
    "ruleName": MessageLookupByLibrary.simpleMessage("ルール名"),
    "ruleSet": MessageLookupByLibrary.simpleMessage("ルールセット"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("ルールターゲット"),
    "rules": MessageLookupByLibrary.simpleMessage("ルール"),
    "rulesCount": m27,
    "save": MessageLookupByLibrary.simpleMessage("保存"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("変更を保存しますか？"),
    "script": MessageLookupByLibrary.simpleMessage("スクリプト"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "スクリプトモード：外部の拡張スクリプトを使用し、ワンクリックで設定を上書きします",
    ),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage("選択項目へスクロール"),
    "search": MessageLookupByLibrary.simpleMessage("検索"),
    "seconds": MessageLookupByLibrary.simpleMessage("秒"),
    "secondsCount": m28,
    "selectAll": MessageLookupByLibrary.simpleMessage("すべて選択"),
    "selectMatchTarget": MessageLookupByLibrary.simpleMessage(
      "MATCH-TARGET を選択",
    ),
    "selectProxies": MessageLookupByLibrary.simpleMessage("プロキシを選択"),
    "selectProxyProviders": MessageLookupByLibrary.simpleMessage(
      "プロキシプロバイダーを選択",
    ),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage("ルールセットを選択してください"),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "振り分け戦略を選択してください",
    ),
    "selectSubRule": MessageLookupByLibrary.simpleMessage("サブルールを選択してください"),
    "selected": MessageLookupByLibrary.simpleMessage("選択済み"),
    "selectedCountTitle": m29,
    "settings": MessageLookupByLibrary.simpleMessage("設定"),
    "show": MessageLookupByLibrary.simpleMessage("表示"),
    "showHiddenGroups": MessageLookupByLibrary.simpleMessage("非表示グループを表示"),
    "showLess": MessageLookupByLibrary.simpleMessage("折りたたむ"),
    "showMore": MessageLookupByLibrary.simpleMessage("展開"),
    "showPassword": MessageLookupByLibrary.simpleMessage("パスワードを表示"),
    "showUnavailable": MessageLookupByLibrary.simpleMessage("タイムアウト表示"),
    "shrink": MessageLookupByLibrary.simpleMessage("コンパクト"),
    "signIn": MessageLookupByLibrary.simpleMessage("サインイン"),
    "signOut": MessageLookupByLibrary.simpleMessage("ログアウト"),
    "signedIn": MessageLookupByLibrary.simpleMessage("サインイン済み"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("サイレント起動"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage("バックグラウンドで起動します"),
    "size": MessageLookupByLibrary.simpleMessage("サイズ"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socks ポート"),
    "sort": MessageLookupByLibrary.simpleMessage("並べ替え"),
    "source": MessageLookupByLibrary.simpleMessage("ソース"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("送信元 IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("特殊プロキシ"),
    "specialRules": MessageLookupByLibrary.simpleMessage("特殊ルール"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage("速度統計"),
    "splitStrategy": MessageLookupByLibrary.simpleMessage("振り分け戦略"),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "振り分け戦略は空にできません",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("SSID が空です"),
    "stackMode": MessageLookupByLibrary.simpleMessage("スタックモード"),
    "standard": MessageLookupByLibrary.simpleMessage("標準"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "標準モード：基本設定を上書きし、シンプルなルール追加機能を提供します",
    ),
    "start": MessageLookupByLibrary.simpleMessage("開始"),
    "startVpn": MessageLookupByLibrary.simpleMessage("VPN を開始中..."),
    "status": MessageLookupByLibrary.simpleMessage("状態"),
    "statusDesc": MessageLookupByLibrary.simpleMessage("無効時はシステム DNS を使用"),
    "stop": MessageLookupByLibrary.simpleMessage("停止"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("VPN を停止中..."),
    "stopped": MessageLookupByLibrary.simpleMessage("停止"),
    "strictRoute": MessageLookupByLibrary.simpleMessage("厳格ルーティング"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "TUN の厳格ルーティングモードを使用",
    ),
    "style": MessageLookupByLibrary.simpleMessage("スタイル"),
    "styleSettings": MessageLookupByLibrary.simpleMessage("スタイル設定"),
    "subRule": MessageLookupByLibrary.simpleMessage("サブルール"),
    "subRuleEmpty": MessageLookupByLibrary.simpleMessage("サブルールが空です"),
    "subRuleNotEmpty": MessageLookupByLibrary.simpleMessage("サブルールは空にできません"),
    "submit": MessageLookupByLibrary.simpleMessage("送信"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage("サブスクリプション情報"),
    "suspendSupport": MessageLookupByLibrary.simpleMessage("サスペンド対応"),
    "suspendSupportDesc": MessageLookupByLibrary.simpleMessage(
      "デバイスがアイドル状態の間、バッテリー消費を抑えるためコアを一時停止します",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("一時停止中..."),
    "swipeToSwitchPage": MessageLookupByLibrary.simpleMessage("スワイプでページ切り替え"),
    "sync": MessageLookupByLibrary.simpleMessage("同期"),
    "system": MessageLookupByLibrary.simpleMessage("システム"),
    "systemApp": MessageLookupByLibrary.simpleMessage("システムアプリ"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("システムプロキシ"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "システムの HTTP プロキシを設定",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("タブ"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("タブアニメーション"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage("モバイル表示でのみ有効です"),
    "tailscaleActive": MessageLookupByLibrary.simpleMessage("アクティブ"),
    "tailscaleCurrentEndpoint": MessageLookupByLibrary.simpleMessage(
      "現在のエンドポイント",
    ),
    "tailscaleDnsName": MessageLookupByLibrary.simpleMessage("DNS 名"),
    "tailscaleEndpoints": MessageLookupByLibrary.simpleMessage("エンドポイント"),
    "tailscaleExitNode": MessageLookupByLibrary.simpleMessage("出口ノード"),
    "tailscaleExitNodeAvailable": MessageLookupByLibrary.simpleMessage(
      "出口ノードとして利用可能",
    ),
    "tailscaleHealth": MessageLookupByLibrary.simpleMessage("ヘルス"),
    "tailscaleHealthWarnings": MessageLookupByLibrary.simpleMessage("ヘルス警告"),
    "tailscaleKeyExpired": MessageLookupByLibrary.simpleMessage("キーの有効期限切れ"),
    "tailscaleKeyExpiry": MessageLookupByLibrary.simpleMessage("キーの有効期限"),
    "tailscaleLastHandshake": MessageLookupByLibrary.simpleMessage("最終ハンドシェイク"),
    "tailscaleLastSeen": MessageLookupByLibrary.simpleMessage("最終確認"),
    "tailscaleNeedsMachineAuth": MessageLookupByLibrary.simpleMessage(
      "デバイスの承認が必要",
    ),
    "tailscaleNodeKey": MessageLookupByLibrary.simpleMessage("ノードキー"),
    "tailscaleRelay": MessageLookupByLibrary.simpleMessage("DERP リレー"),
    "tailscaleSubnets": MessageLookupByLibrary.simpleMessage("サブネット"),
    "tailscaleTags": MessageLookupByLibrary.simpleMessage("タグ"),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage("タップして許可"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP 並列処理"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage("TCP 並列処理を許可"),
    "testInterval": MessageLookupByLibrary.simpleMessage("テスト間隔"),
    "testUrl": MessageLookupByLibrary.simpleMessage("URL テスト"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("使用時にテスト"),
    "textScale": MessageLookupByLibrary.simpleMessage("テキストの拡大縮小"),
    "theme": MessageLookupByLibrary.simpleMessage("テーマ"),
    "themeColor": MessageLookupByLibrary.simpleMessage("テーマカラー"),
    "themeDesc": MessageLookupByLibrary.simpleMessage("ダークモードの設定と色の調整"),
    "themeMode": MessageLookupByLibrary.simpleMessage("テーマモード"),
    "tight": MessageLookupByLibrary.simpleMessage("コンパクト"),
    "time": MessageLookupByLibrary.simpleMessage("時刻"),
    "timeout": MessageLookupByLibrary.simpleMessage("タイムアウト"),
    "tip": MessageLookupByLibrary.simpleMessage("ヒント"),
    "toggle": MessageLookupByLibrary.simpleMessage("切り替え"),
    "toggleLabel": MessageLookupByLibrary.simpleMessage("ラベルを切り替え"),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("トーナルスポット"),
    "tools": MessageLookupByLibrary.simpleMessage("ツール"),
    "torch": MessageLookupByLibrary.simpleMessage("ライト"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("合計トラフィック"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("TProxy ポート"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("トラフィック統計"),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunDesc": MessageLookupByLibrary.simpleMessage("管理者モードでのみ有効"),
    "turnOff": MessageLookupByLibrary.simpleMessage("オフにする"),
    "turnOn": MessageLookupByLibrary.simpleMessage("オンにする"),
    "uiUpdateIdleInterval": MessageLookupByLibrary.simpleMessage("アイドル更新間隔"),
    "uiUpdateIdleWhenUnfocused": MessageLookupByLibrary.simpleMessage(
      "フォーカス喪失時にアイドル",
    ),
    "uiUpdateIdleWhenUnfocusedDesc": MessageLookupByLibrary.simpleMessage(
      "アプリウィンドウがフォーカスを失ったときにアイドル更新間隔を使用",
    ),
    "uiUpdateInterval": MessageLookupByLibrary.simpleMessage("UI 情報の更新間隔"),
    "uiUpdateIntervalDesc": m30,
    "uiUpdateIntervalIdleDisabledDesc": m31,
    "unauthorized": MessageLookupByLibrary.simpleMessage("未許可"),
    "undo": MessageLookupByLibrary.simpleMessage("元に戻す"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("統一遅延"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "ハンドシェイクなどの余分な遅延を除きます",
    ),
    "uninitialized": MessageLookupByLibrary.simpleMessage("未初期化"),
    "unknown": MessageLookupByLibrary.simpleMessage("不明"),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage("不明なネットワークエラー"),
    "unmaximize": MessageLookupByLibrary.simpleMessage("元に戻す"),
    "unnamed": MessageLookupByLibrary.simpleMessage("名称未設定"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage("固定を解除"),
    "update": MessageLookupByLibrary.simpleMessage("更新"),
    "upload": MessageLookupByLibrary.simpleMessage("アップロード"),
    "uploadSpeed": MessageLookupByLibrary.simpleMessage("アップロード速度"),
    "uploadTraffic": MessageLookupByLibrary.simpleMessage("アップロード通信量"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage("URL 経由でプロファイルを取得"),
    "urlTip": m32,
    "useHosts": MessageLookupByLibrary.simpleMessage("Hostsを使用"),
    "useHostsDesc": MessageLookupByLibrary.simpleMessage(
      "上流 DNS へ問い合わせる前に、設定内の hosts エントリを確認します",
    ),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("システムのHostsを使用"),
    "useSystemHostsDesc": MessageLookupByLibrary.simpleMessage(
      "ドメイン名の解決時に OS の Hosts ファイルを確認します",
    ),
    "usedTraffic": MessageLookupByLibrary.simpleMessage("使用済みトラフィック"),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "value": MessageLookupByLibrary.simpleMessage("値"),
    "version": MessageLookupByLibrary.simpleMessage("バージョン"),
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("ビブラント"),
    "view": MessageLookupByLibrary.simpleMessage("表示"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "VPN 設定の変更が検出されました",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "VpnService 経由で全システムトラフィックをルーティング",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage("変更は VPN 再起動後に有効"),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage("WebDAV 設定"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("ホワイトリストモード"),
    "yearsAgo": m33,
    "zhCN": MessageLookupByLibrary.simpleMessage("簡体字中国語"),
  };
}

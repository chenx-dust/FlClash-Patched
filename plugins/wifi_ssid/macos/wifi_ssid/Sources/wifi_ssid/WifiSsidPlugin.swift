import Cocoa
import CoreLocation
import CoreWLAN
import FlutterMacOS

// Permission values must match WifiSsidPermission enum index in Dart:
//   0 = granted, 1 = denied, 2 = permanentlyDenied
public class WifiSsidPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate {

    private let locationManager = CLLocationManager()
    private var pendingPermissionResult: FlutterResult?
    private let ssidQueue = DispatchQueue(label: "com.follow.clash.wifi-ssid", qos: .utility)
    private let ssidTimeout: TimeInterval = 2.0

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "wifi_ssid",
            binaryMessenger: registrar.messenger
        )
        let instance = WifiSsidPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    override init() {
        super.init()
        locationManager.delegate = self
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getSsid":
            getSsid(result: result)
        case "checkPermission":
            checkPermission(result: result)
        case "requestPermission":
            requestPermission(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Permission

    private func checkPermission(result: @escaping FlutterResult) {
        let status = locationManager.authorizationStatus
        result(mapAuthStatus(status).rawValue)
    }

    private func requestPermission(result: @escaping FlutterResult) {
        let status = locationManager.authorizationStatus
        if isAuthorized(status) {
            result(0) // granted
            return
        }
        if status == .denied || status == .restricted {
            result(2) // permanentlyDenied
            return
        }
        if pendingPermissionResult != nil {
            result(mapAuthStatus(status).rawValue)
            return
        }
        pendingPermissionResult = result
        locationManager.requestWhenInUseAuthorization()
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let result = pendingPermissionResult else { return }
        pendingPermissionResult = nil
        result(mapAuthStatus(manager.authorizationStatus).rawValue)
    }

    private func mapAuthStatus(_ status: CLAuthorizationStatus) -> WifiSsidPermission {
        if isAuthorized(status) {
            return .granted
        }
        switch status {
        case .denied, .restricted:
            return .permanentlyDenied
        default:
            return .denied
        }
    }

    private func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        switch status {
        case .authorizedAlways:
            return true
        case .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    private enum WifiSsidPermission: Int {
        case granted = 0
        case denied = 1
        case permanentlyDenied = 2
    }

    // MARK: - SSID

    private func getSsid(result: @escaping FlutterResult) {
        guard isAuthorized(locationManager.authorizationStatus) else {
            result(nil)
            return
        }

        guard #available(macOS 10.10, *) else {
            result(nil)
            return
        }

        var didComplete = false
        let lock = NSLock()

        func complete(_ value: String?) {
            lock.lock()
            defer { lock.unlock() }
            guard !didComplete else { return }
            didComplete = true
            DispatchQueue.main.async {
                result(value)
            }
        }

        ssidQueue.async {
            let ssid = CWWiFiClient.shared().interface()?.ssid()
            complete(ssid)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + ssidTimeout) {
            complete(nil)
        }
    }
}

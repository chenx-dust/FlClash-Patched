import CoreLocation
import Flutter
import NetworkExtension
import UIKit

public class WifiSsidPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var pendingPermissionResult: FlutterResult?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "wifi_ssid",
            binaryMessenger: registrar.messenger()
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

    private func checkPermission(result: @escaping FlutterResult) {
        result(mapAuthStatus(locationManager.authorizationStatus).rawValue)
    }

    private func requestPermission(result: @escaping FlutterResult) {
        let status = locationManager.authorizationStatus
        let permission = mapAuthStatus(status)
        if permission != .denied || status != .notDetermined {
            result(permission.rawValue)
            return
        }
        if pendingPermissionResult != nil {
            result(permission.rawValue)
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

    public func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        guard let result = pendingPermissionResult else { return }
        pendingPermissionResult = nil
        result(mapAuthStatus(status).rawValue)
    }

    private func mapAuthStatus(_ status: CLAuthorizationStatus) -> WifiSsidPermission {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return .granted
        case .denied, .restricted:
            return .permanentlyDenied
        case .notDetermined:
            return .denied
        @unknown default:
            return .denied
        }
    }

    private func getSsid(result: @escaping FlutterResult) {
        NEHotspotNetwork.fetchCurrent { network in
            let ssid = network?.ssid
            result(ssid?.isEmpty == false ? ssid : nil)
        }
    }

    private enum WifiSsidPermission: Int {
        case granted = 0
        case denied = 1
        case permanentlyDenied = 2
    }
}

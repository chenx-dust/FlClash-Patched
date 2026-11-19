import Darwin
import Flutter
import Foundation
import SafariServices
import Security
import UIKit

@MainActor
final class MitmTrustPlugin {
  private static let channelName = "com.follow.clash/mitm_trust"
  private static var instance: MitmTrustPlugin?

  private let channel: FlutterMethodChannel
  private var activeSession: ProfileInstallSession?

  static func register(with messenger: FlutterBinaryMessenger) {
    instance = MitmTrustPlugin(messenger: messenger)
  }

  private init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      MainActor.assumeIsolated {
        guard let self else {
          result(FlutterMethodNotImplemented)
          return
        }
        self.handle(call, result: result)
      }
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "verifyCaCertificate":
      handleVerifyCaCertificate(call, result: result)
    case "installCaProfile":
      handleInstallCaProfile(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleVerifyCaCertificate(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
      let leafDer = (args["leafDer"] as? FlutterStandardTypedData)?.data,
      let caDer = (args["caDer"] as? FlutterStandardTypedData)?.data,
      let host = args["host"] as? String
    else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENT",
          message: "Expected leafDer, caDer, and host",
          details: nil
        )
      )
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      let status = Self.evaluateTrust(leafDer: leafDer, caDer: caDer, host: host)
      DispatchQueue.main.async {
        result(status)
      }
    }
  }

  // Evaluate against the system trust store without setting custom anchors so
  // user Certificate Trust Settings decide whether the CA is trusted.
  private nonisolated static func evaluateTrust(
    leafDer: Data,
    caDer: Data,
    host: String
  ) -> String {
    guard let leaf = SecCertificateCreateWithData(nil, leafDer as CFData) else {
      return "notInstalled"
    }
    let policy = SecPolicyCreateSSL(true, host as CFString)
    var trustRef: SecTrust?
    guard
      SecTrustCreateWithCertificates([leaf] as CFArray, policy, &trustRef)
        == errSecSuccess,
      let trust = trustRef
    else {
      return "notInstalled"
    }
    SecTrustSetNetworkFetchAllowed(trust, false)
    var error: CFError?
    let trusted = SecTrustEvaluateWithError(trust, &error)
    let chain = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
    let hasCa = chain.contains { (SecCertificateCopyData($0) as Data) == caDer }
    if trusted && hasCa {
      return "ready"
    }
    return hasCa ? "untrusted" : "notInstalled"
  }

  private func handleInstallCaProfile(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
      let profile = (args["profile"] as? FlutterStandardTypedData)?.data,
      let fileName = args["fileName"] as? String
    else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENT",
          message: "Expected profile and fileName",
          details: nil
        )
      )
      return
    }
    activeSession?.finish(with: nil)
    activeSession = nil

    let server: LocalProfileServer
    do {
      server = try LocalProfileServer(payload: profile, fileName: fileName)
    } catch {
      result(
        FlutterError(
          code: "SERVER_ERROR",
          message: error.localizedDescription,
          details: nil
        )
      )
      return
    }

    guard let presenter = topViewController() else {
      server.stop()
      result(
        FlutterError(
          code: "UNAVAILABLE",
          message: "No view controller available",
          details: nil
        )
      )
      return
    }

    // SFSafariViewController shares Safari's configuration profile download
    // handler without leaving the user's preferred default browser tab clutter.
    let configuration = SFSafariViewController.Configuration()
    configuration.entersReaderIfAvailable = false
    configuration.barCollapsingEnabled = false
    let safari = SFSafariViewController(url: server.url, configuration: configuration)
    safari.dismissButtonStyle = .done

    let session = ProfileInstallSession(server: server, result: result) {
      [weak self] in
      self?.activeSession = nil
    }
    safari.delegate = session
    safari.presentationController?.delegate = session
    activeSession = session
    presenter.present(safari, animated: true)
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    let activeScene =
      scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    let keyWindow =
      activeScene?.windows.first(where: \.isKeyWindow)
      ?? activeScene?.windows.first
    var top = keyWindow?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}

@MainActor
private final class ProfileInstallSession: NSObject,
  SFSafariViewControllerDelegate,
  UIAdaptivePresentationControllerDelegate
{
  private var server: LocalProfileServer?
  private var result: FlutterResult?
  private let onComplete: () -> Void

  init(
    server: LocalProfileServer,
    result: @escaping FlutterResult,
    onComplete: @escaping () -> Void
  ) {
    self.server = server
    self.result = result
    self.onComplete = onComplete
  }

  func finish(with value: String?) {
    guard let result else {
      return
    }
    self.result = nil
    server?.stop()
    server = nil
    onComplete()
    result(value)
  }

  nonisolated func safariViewControllerDidFinish(
    _ controller: SFSafariViewController
  ) {
    MainActor.assumeIsolated {
      finish(with: "prompted")
    }
  }

  func presentationControllerDidDismiss(
    _ presentationController: UIPresentationController
  ) {
    finish(with: "prompted")
  }
}

private final class LocalProfileServer: @unchecked Sendable {
  let url: URL

  private let payload: Data
  private let expectedPath: String
  private let contentDisposition: String
  private let queue = DispatchQueue(label: "com.follow.clash.mitmProfileServer")
  private let stateLock = NSLock()
  private var source: DispatchSourceRead?
  private var stopped = false

  init(payload: Data, fileName: String) throws {
    let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    var closeOnError = true
    defer {
      if closeOnError {
        Darwin.close(fd)
      }
    }

    var noSigPipe: Int32 = 1
    Darwin.setsockopt(
      fd,
      SOL_SOCKET,
      SO_NOSIGPIPE,
      &noSigPipe,
      socklen_t(MemoryLayout<Int32>.size)
    )
    let flags = Darwin.fcntl(fd, F_GETFL, 0)
    if flags >= 0 {
      _ = Darwin.fcntl(fd, F_SETFL, flags | O_NONBLOCK)
    }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = 0
    address.sin_addr = in_addr(s_addr: INADDR_LOOPBACK.bigEndian)

    let bindStatus = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { addrPtr in
        Darwin.bind(fd, addrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard bindStatus == 0 else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EADDRINUSE)
    }

    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameStatus = withUnsafeMutablePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { addrPtr in
        Darwin.getsockname(fd, addrPtr, &length)
      }
    }
    guard nameStatus == 0 else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    guard Darwin.listen(fd, 8) == 0 else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }

    let port = UInt16(bigEndian: address.sin_port)
    let path = "/\(UUID().uuidString)/FlClash-CA.mobileconfig"
    guard let serverUrl = URL(string: "http://127.0.0.1:\(port)\(path)") else {
      throw POSIXError(.EINVAL)
    }

    self.url = serverUrl
    self.payload = payload
    self.expectedPath = path
    let safeName = Self.sanitizeFileName(fileName)
    self.contentDisposition = "attachment; filename=\"\(safeName)\""

    let readSource = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
    readSource.setEventHandler { [weak self] in
      self?.acceptPending(listenFd: fd)
    }
    readSource.setCancelHandler {
      Darwin.close(fd)
    }
    self.source = readSource
    closeOnError = false
    readSource.resume()
  }

  deinit {
    stop()
  }

  func stop() {
    let activeSource: DispatchSourceRead? = stateLock.withLock {
      guard !stopped else {
        return nil
      }
      stopped = true
      let current = source
      source = nil
      return current
    }
    activeSource?.cancel()
  }

  private func acceptPending(listenFd: Int32) {
    while true {
      let clientFd = Darwin.accept(listenFd, nil, nil)
      if clientFd < 0 {
        if errno == EINTR {
          continue
        }
        break
      }
      // Accepted sockets on Darwin inherit O_NONBLOCK from the listener.
      let clientFlags = Darwin.fcntl(clientFd, F_GETFL, 0)
      if clientFlags >= 0 && (clientFlags & O_NONBLOCK) != 0 {
        _ = Darwin.fcntl(clientFd, F_SETFL, clientFlags & ~O_NONBLOCK)
      }
      let expectedPath = self.expectedPath
      let contentDisposition = self.contentDisposition
      let payload = self.payload
      DispatchQueue.global(qos: .userInitiated).async {
        Self.handleClient(
          clientFd,
          expectedPath: expectedPath,
          contentDisposition: contentDisposition,
          payload: payload
        )
      }
    }
  }

  private static func handleClient(
    _ fd: Int32,
    expectedPath: String,
    contentDisposition: String,
    payload: Data
  ) {
    defer { Darwin.close(fd) }

    var noSigPipe: Int32 = 1
    Darwin.setsockopt(
      fd,
      SOL_SOCKET,
      SO_NOSIGPIPE,
      &noSigPipe,
      socklen_t(MemoryLayout<Int32>.size)
    )
    var timeout = timeval(tv_sec: 5, tv_usec: 0)
    Darwin.setsockopt(
      fd,
      SOL_SOCKET,
      SO_RCVTIMEO,
      &timeout,
      socklen_t(MemoryLayout<timeval>.size)
    )
    Darwin.setsockopt(
      fd,
      SOL_SOCKET,
      SO_SNDTIMEO,
      &timeout,
      socklen_t(MemoryLayout<timeval>.size)
    )

    guard let requestLine = readRequestLine(fd) else {
      return
    }
    let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
    guard parts.count >= 2 else {
      writeResponse(fd, status: "400 Bad Request", headers: ["Content-Length: 0"])
      return
    }
    let method = String(parts[0])
    let rawTarget = String(parts[1])
    let path =
      rawTarget.split(
        separator: "?",
        maxSplits: 1,
        omittingEmptySubsequences: false
      ).first.map(String.init) ?? rawTarget

    guard method == "GET" || method == "HEAD" else {
      writeResponse(
        fd,
        status: "405 Method Not Allowed",
        headers: ["Content-Length: 0"]
      )
      return
    }
    guard path == expectedPath else {
      writeResponse(fd, status: "404 Not Found", headers: ["Content-Length: 0"])
      return
    }
    writeResponse(
      fd,
      status: "200 OK",
      headers: [
        "Content-Type: application/x-apple-aspen-config",
        "Content-Disposition: \(contentDisposition)",
        "Content-Length: \(payload.count)",
        "Cache-Control: no-store",
      ],
      body: method == "GET" ? payload : nil
    )
  }

  private static func readRequestLine(_ fd: Int32) -> String? {
    var received = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    let headerEnd = Data("\r\n\r\n".utf8)
    while received.count < 4096 {
      let count = buffer.withUnsafeMutableBytes { rawBuffer in
        Darwin.recv(fd, rawBuffer.baseAddress, rawBuffer.count, 0)
      }
      if count < 0 {
        if errno == EINTR {
          continue
        }
        break
      }
      if count == 0 {
        break
      }
      received.append(contentsOf: buffer.prefix(count))
      if received.range(of: headerEnd) != nil {
        break
      }
    }
    guard let text = String(data: received, encoding: .utf8) else {
      return nil
    }
    return text.components(separatedBy: "\r\n").first
  }

  private static func writeResponse(
    _ fd: Int32,
    status: String,
    headers: [String],
    body: Data? = nil
  ) {
    let head =
      (["HTTP/1.1 \(status)"] + headers + ["Connection: close", "", ""])
      .joined(separator: "\r\n")
    guard writeAll(fd, Data(head.utf8)) else {
      return
    }
    if let body, !body.isEmpty {
      _ = writeAll(fd, body)
    }
  }

  private static func writeAll(_ fd: Int32, _ data: Data) -> Bool {
    data.withUnsafeBytes { rawBuffer in
      guard let base = rawBuffer.baseAddress else {
        return true
      }
      var offset = 0
      while offset < rawBuffer.count {
        let written = Darwin.send(
          fd,
          base.advanced(by: offset),
          rawBuffer.count - offset,
          0
        )
        if written > 0 {
          offset += written
        } else if written < 0 && errno == EINTR {
          continue
        } else {
          return false
        }
      }
      return true
    }
  }

  private static func sanitizeFileName(_ raw: String) -> String {
    let cleaned = String(
      raw.unicodeScalars.map { scalar in
        switch scalar.value {
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x20, 0x2D, 0x2E, 0x5F:
          return Character(scalar)
        default:
          return "_"
        }
      }
    ).trimmingCharacters(in: CharacterSet(charactersIn: " ."))
    return cleaned.isEmpty ? "FlClash-CA.mobileconfig" : cleaned
  }
}

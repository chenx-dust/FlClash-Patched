import ClashCore
import Foundation

final class CoreResultHandler: NSObject, MobileResultHandlerProtocol {
  private let handler: (Data) -> Void

  init(_ handler: @escaping (Data) -> Void) {
    self.handler = handler
  }

  func onResult(_ data: Data?) throws {
    handler(data ?? Data())
  }
}

// The extension's sockets bypass its own tunnel, and iOS names no connection owner.
final class CoreTunHandler: NSObject, MobileTunHandlerProtocol {
  func protect(_ fd: Int32, ret0_: UnsafeMutablePointer<ObjCBool>?) throws {
    ret0_?.pointee = true
  }

  func resolvePackage(_ uid: Int32, error: NSErrorPointer) -> String {
    ""
  }

  func resolveUid(
    _ protocol: Int32,
    source: String?,
    target: String?,
    ret0_: UnsafeMutablePointer<Int32>?
  ) throws {
    ret0_?.pointee = -1
  }
}

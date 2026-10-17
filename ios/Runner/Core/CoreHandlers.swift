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

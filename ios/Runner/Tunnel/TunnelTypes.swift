import Foundation
import NetworkExtension

enum TunnelTarget {
  case running
  case stopped

  var description: String {
    switch self {
    case .running:
      return "running"
    case .stopped:
      return "stopped"
    }
  }
}

extension NEVPNStatus {
  var tunnelState: TunnelTarget? {
    switch self {
    case .connected, .reasserting:
      return .running
    case .disconnected, .invalid:
      return .stopped
    case .connecting, .disconnecting:
      return nil
    @unknown default:
      return nil
    }
  }

  var isLifecycleActive: Bool {
    tunnelState != .stopped
  }

  var isTerminal: Bool {
    tunnelState == .stopped
  }
}

final class TunnelRequest {
  let generation: UInt64
  let target: TunnelTarget
  var completions: [(Bool) -> Void]
  var preferenceRetryCount = 0

  init(
    generation: UInt64,
    target: TunnelTarget,
    completion: @escaping (Bool) -> Void
  ) {
    self.generation = generation
    self.target = target
    completions = [completion]
  }
}

enum TunnelWaitPurpose {
  case starting
  case stopping
  case settleThenStart

  var description: String {
    switch self {
    case .starting:
      return "starting"
    case .stopping:
      return "stopping"
    case .settleThenStart:
      return "settleThenStart"
    }
  }
}

enum TunnelWaitResult {
  case status(NEVPNStatus)
  case timeout(NEVPNStatus)
  case superseded
}

final class TunnelWait {
  let request: TunnelRequest
  let purpose: TunnelWaitPurpose
  let manager: NETunnelProviderManager
  let continuation: CheckedContinuation<TunnelWaitResult, Never>
  var hasObservedProgress = false
  var timeoutWork: DispatchWorkItem?

  init(
    request: TunnelRequest,
    purpose: TunnelWaitPurpose,
    manager: NETunnelProviderManager,
    continuation: CheckedContinuation<TunnelWaitResult, Never>
  ) {
    self.request = request
    self.purpose = purpose
    self.manager = manager
    self.continuation = continuation
  }
}

struct ProviderMessageError {
  let code: String
  let message: String
}

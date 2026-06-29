import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let handler = completionHandler else {
            return
        }

        guard let object = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] else {
            handler(actionResult(method: "message", id: nil, data: "invalid action", code: -1))
            return
        }

        let method = object["method"] as? String ?? "message"
        let id = object["id"] as? String
        let data = object["data"] ?? NSNull()
        handler(actionResult(method: method, id: id, data: data, code: 0))
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }

    private func actionResult(method: String, id: String?, data: Any, code: Int) -> Data? {
        var payload: [String: Any] = [
            "method": method,
            "data": data,
            "code": code,
        ]
        if let id = id {
            payload["id"] = id
        }
        return try? JSONSerialization.data(withJSONObject: payload)
    }
}

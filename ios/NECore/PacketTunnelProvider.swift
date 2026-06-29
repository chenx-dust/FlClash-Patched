import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        NECoreBridge.stopTun()
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let handler = completionHandler else {
            return
        }

        guard let action = String(data: messageData, encoding: .utf8) else {
            handler(actionResult(messageData: nil, message: "invalid action"))
            return
        }

        NECoreBridge.invokeAction(action) { response in
            guard let response = response, let data = response.data(using: .utf8) else {
                handler(self.actionResult(messageData: messageData, message: "empty core response"))
                return
            }
            handler(data)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }

    private func actionResult(messageData: Data?, message: String) -> Data? {
        var method = "message"
        var id: String?
        if let messageData,
           let object = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] {
            method = object["method"] as? String ?? method
            id = object["id"] as? String
        }
        var payload: [String: Any] = [
            "method": method,
            "data": message,
            "code": -1,
        ]
        if let id = id {
            payload["id"] = id
        }
        return try? JSONSerialization.data(withJSONObject: payload)
    }
}

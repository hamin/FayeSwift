//
//  WebsocketTransport.swift
//  Pods
//
//  Created by Haris Amin on 2/20/16.
//
//

import Foundation
import Starscream

class WebsocketTransport: Transport {
    var urlString:String?
    var webSocket:WebSocket?
    var headers: [String: String]? = nil
    weak var delegate:TransportDelegate?
    private var socketConnected: Bool = false

    var isConnected: Bool {
        return socketConnected
    }

    convenience required internal init(url: String) {
        self.init()

        self.urlString = url
    }

    func openConnection() {
        self.closeConnection()
        guard let urlString = urlString,
            let url = URL(string: urlString) else {
                print("Faye: Invalid url")
                return
        }
        var urlRequest = URLRequest(url: url)
        if let headers = self.headers {
            urlRequest.allHTTPHeaderFields = headers
        }
        self.webSocket = WebSocket(request: urlRequest)

        if let webSocket = self.webSocket {
            webSocket.delegate = self
            webSocket.connect()
            print("Faye: Opening connection with \(self.urlString)")
        }
    }

    func closeConnection() {
        if let webSocket = self.webSocket {
            print("Faye: Closing connection")

            webSocket.delegate = nil
            webSocket.disconnect()

            self.webSocket = nil
        }
    }

    func writeString(_ aString:String) {
        self.webSocket?.write(string: aString)
    }

    func sendPing(_ data: Data, completion: (() -> ())? = nil) {
        self.webSocket?.write(ping: data, completion: completion)
    }

    func websocketDidDisconnect(withReason reason: String?, andCode code: UInt16?) {
        if let reason = reason,
            let code = code {
            self.delegate?.didDisconnect(.connectionLost(reason: reason, code: code))
        } else {
            self.delegate?.didDisconnect(.connectionDisconnected)
        }
    }
}

extension WebsocketTransport: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(let headers):
            print("websocket is connected: \(headers)")
            socketConnected = true
            self.delegate?.didConnect()
        case .disconnected(let reason, let code):
            socketConnected = false
            print("websocket is disconnected for reason: \(reason) /n with code: \(code)")
            websocketDidDisconnect(withReason: reason, andCode: code)
        case .text(let text):
            self.delegate?.didReceiveMessage(text)
        case .binary(let data):
            print("Faye: Received data: \(data.count)")
            self.delegate?.didReceiveData(data)
        case .pong(let data):
            // FIXME: Data should be forwarded on
            self.delegate?.didReceivePong()
        case .ping(let data):
            self.delegate?.didReceivePing()
        case .error(let error):
            break
        case .viablityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            break
        @unknown default:
            break
        }
    }
}

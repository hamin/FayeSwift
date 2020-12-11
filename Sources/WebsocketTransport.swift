//
//  WebsocketTransport.swift
//  Pods
//
//  Created by Haris Amin on 2/20/16.
//
//

import Foundation
import Starscream

internal class WebsocketTransport: Transport, WebSocketDelegate {

  var urlString:String?
  var webSocket:WebSocket?
  var headers: [String: String]? = nil
  internal weak var delegate:TransportDelegate?
  private var socketConnected: Bool = false
  
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

        print("Faye: Opening connection with \(String(describing: self.urlString))")
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
  
  func isConnected() -> (Bool) {
    return self.socketConnected
  }

    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(let headers):
            print("websocket is connected: \(headers)")
            socketConnected = true
            self.delegate?.didConnect()
        case .disconnected(let reason, let code):
            socketConnected = false
            print("websocket is disconnected for reason: \(reason) /n with code: \(code)")
            //TODO: FIX CODES
            self.delegate?.didDisconnect(NSError(error: .lostConnection))
        case .text(let text):
            self.delegate?.didReceiveMessage(text)
        case .pong(_):
            self.delegate?.didReceivePong()
        case .binary(_):
            //TODO: ADD THIS
            break
        case .error(_):
            break
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            break
        case .ping(_):
            //TODO: ADD THIS
            break
        }
    }
}

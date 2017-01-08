//
//  WebsocketTransport.swift
//  Pods
//
//  Created by Haris Amin on 2/20/16.
//
//

import Foundation
import Starscream

internal class WebsocketTransport: Transport, WebSocketDelegate, WebSocketPongDelegate {
  var urlString:String?
  var webSocket:WebSocket?
  internal weak var delegate:TransportDelegate?
  
  convenience required internal init(url: String) {
    self.init()
    
    self.urlString = url
  }
  
  func openConnection() {
    self.closeConnection()
    self.webSocket = WebSocket(url: URL(string:self.urlString!)!)
    
    if let webSocket = self.webSocket {
      webSocket.delegate = self
      webSocket.pongDelegate = self
      webSocket.connect()
        
      print("Faye: Opening connection with \(self.urlString)")
    }
  }
  
  func closeConnection() {
    if let webSocket = self.webSocket {
      print("Faye: Closing connection")
        
      webSocket.delegate = nil
      webSocket.disconnect(forceTimeout: 0)
      
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
    return self.webSocket?.isConnected ?? false
  }
  
  // MARK: Websocket Delegate
  internal func websocketDidConnect(socket: WebSocket) {
    self.delegate?.didConnect()
  }
  
  internal func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
    if error == nil {
      self.delegate?.didDisconnect(NSError(error: .lostConnection))
    } else {
      self.delegate?.didFailConnection(error)
    }
  }
  
  internal func websocketDidReceiveMessage(socket: WebSocket, text: String) {
    self.delegate?.didReceiveMessage(text)
  }
  
  // MARK: TODO
  internal func websocketDidReceiveData(socket: WebSocket, data: Data) {
    print("Faye: Received data: \(data.count)")
    //self.socket.writeData(data)
  }

  // MARK: WebSocket Pong Delegate
  internal func websocketDidReceivePong(_ socket: WebSocket) {
    self.delegate?.didReceivePong()
  }
    
  func websocketDidReceivePong(socket: WebSocket, data: Data?) {
    self.delegate?.didReceivePong()
  }
}

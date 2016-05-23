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
  internal weak var delegate:TransportDelegate?
  
  convenience required internal init(url: String) {
    self.init()
    self.urlString = url
  }
  
  func openConnection() {
    self.closeConnection()
    self.webSocket = WebSocket(url: NSURL(string:self.urlString!)!)
    
    if let webSocket = self.webSocket {
      webSocket.delegate = self;
      webSocket.connect()
    }
  }
  
  func closeConnection() {
    if let webSocket = self.webSocket {
      webSocket.delegate = nil
      webSocket.disconnect()
      self.webSocket = nil
    }
  }
  
  func writeString(aString:String) {
    self.webSocket?.writeString(aString)
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
      self.delegate?.didDisconnect(NSError(error: .LostConnection))
    } else {
      self.delegate?.didFailConnection(error)
    }
  }
  
  internal func websocketDidReceiveMessage(socket: WebSocket, text: String) {
    self.delegate?.didReceiveMessage(text)
  }
  
  // MARK: TODO
  internal func websocketDidReceiveData(socket: WebSocket, data: NSData) {
    print("got some data: \(data.length)")
    //self.socket.writeData(data)
  }
}
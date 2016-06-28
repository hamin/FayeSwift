//
//  Transport.swift
//  Pods
//
//  Created by Haris Amin on 2/20/16.
//
//

public protocol Transport {
  func writeString(aString:String)
  func openConnection()
  func closeConnection()
  func isConnected() -> (Bool)
}

public protocol TransportDelegate: class {
  func didConnect()
  func didFailConnection(error:NSError?)
  func didDisconnect(error: NSError?)
  func didWriteError(error:NSError?)
  func didReceiveMessage(text:String)
  func didReceivePong()
}
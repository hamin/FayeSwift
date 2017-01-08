//
//  Transport.swift
//  Pods
//
//  Created by Haris Amin on 2/20/16.
//
//

public protocol Transport {
  func writeString(_ aString:String)
  func openConnection()
  func closeConnection()
  func isConnected() -> (Bool)
}

public protocol TransportDelegate: class {
  func didConnect()
  func didFailConnection(_ error:NSError?)
  func didDisconnect(_ error: NSError?)
  func didWriteError(_ error:NSError?)
  func didReceiveMessage(_ text:String)
  func didReceivePong()
}

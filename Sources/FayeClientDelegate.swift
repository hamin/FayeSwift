//
//  FayeClientDelegate.swift
//  Pods
//
//  Created by Haris Amin on 2/20/16.
//
//

import Foundation

public enum subscriptionError: Error {
    case error(subscription: String, error: String)
}

// MARK: FayeClientDelegate Protocol
public protocol FayeClientDelegate: NSObjectProtocol {
  func messageReceived(_ client:FayeClient, messageDict: NSDictionary, channel: String)
  func pongReceived(_ client:FayeClient)
  func connectedToServer(_ client:FayeClient)
  func disconnectedFromServer(_ client:FayeClient)
  func connectionFailed(_ client:FayeClient)
  func didSubscribeToChannel(_ client:FayeClient, channel:String)
  func didUnsubscribeFromChannel(_ client:FayeClient, channel:String)
  func subscriptionFailedWithError(_ client:FayeClient, error:subscriptionError)
  func fayeClientError(_ client:FayeClient, error:NSError)
}

public extension FayeClientDelegate {
  func messageReceived(_ client:FayeClient, messageDict: NSDictionary, channel: String){}
  func pongReceived(_ client:FayeClient){}
  func connectedToServer(_ client:FayeClient){}
  func disconnectedFromServer(_ client:FayeClient){}
  func connectionFailed(_ client:FayeClient){}
  func didSubscribeToChannel(_ client:FayeClient, channel:String){}
  func didUnsubscribeFromChannel(_ client:FayeClient, channel:String){}
  func subscriptionFailedWithError(_ client:FayeClient, error:subscriptionError){}
  func fayeClientError(_ client:FayeClient, error:NSError){}
}

//
//  FayeClient.swift
//  FayeSwift
//
//  Created by Haris Amin on 8/31/14.
//  Copyright (c) 2014 Haris Amin. All rights reserved.
//

import Foundation
import SwiftyJSON

// MARK: BayuexChannel Messages
enum BayeuxChannel : String {
  case Handshake = "/meta/handshake";
  case Connect = "/meta/connect";
  case Disconnect = "/meta/disconnect";
  case Subscribe = "/meta/subscribe";
  case Unsubscibe = "/meta/unsubscribe";
}


// MARK: Type Aliases
public typealias ChannelSubscriptionBlock = (NSDictionary) -> Void


// MARK: FayeClient
public class FayeClient : TransportDelegate {
  public var fayeURLString:String
  public var fayeClientId:String?
  public weak var delegate:FayeClientDelegate?
  
  private var transport:WebsocketTransport?
  private var fayeConnected:Bool?
  private var connectionExtension:NSDictionary?
  private var connectionInitiated:Bool?
  private var messageNumber:UInt32 = 0

  private var queuedSubscriptions = Set<String>()
  private var pendingSubscriptions = Set<String>()
  private var openSubscriptions = Set<String>()

  private var channelSubscriptionBlocks = Dictionary<String,ChannelSubscriptionBlock>()

  public init(aFayeURLString:String, channel:String?) {
    self.fayeURLString = aFayeURLString
    self.fayeConnected = false;

    self.transport = WebsocketTransport(url: aFayeURLString)
    self.transport!.delegate = self;

    if let chan = channel {
      self.queuedSubscriptions.insert(chan)
    }
    self.connectionInitiated = false
  }

  public convenience init(aFayeURLString:String, channel:String, channelBlock:ChannelSubscriptionBlock) {
    self.init(aFayeURLString: aFayeURLString, channel: channel)
    self.channelSubscriptionBlocks[channel] = channelBlock;
  }

  public func connectToServer() {
    if self.connectionInitiated != true {
      self.transport?.openConnection()
      self.connectionInitiated = true;
    }
  }

  public func disconnectFromServer() {
    self.disconnect()
  }

  public func sendMessage(messageDict: NSDictionary, channel:String) {
    self.publish(messageDict as! Dictionary, channel: channel)
  }

  public func sendMessage(messageDict:[String:AnyObject], channel:String) {
    self.publish(messageDict, channel: channel)
  }

  public func subscribeToChannel(channel:String) {
    if self.isSubscribedToChannel(channel) || self.pendingSubscriptions.contains(channel) {
      return
    }

    if self.fayeConnected == true {
      self.subscribe(channel)
    } else {
      self.queuedSubscriptions.insert(channel)
    }
  }

  public func subscribeToChannel(channel:String, block:ChannelSubscriptionBlock) {
    self.subscribeToChannel(channel)
    self.channelSubscriptionBlocks[channel] = block;
  }

  public func unsubscribeFromChannel(channel:String) {
    self.queuedSubscriptions.remove(channel)
    self.unsubscribe(channel)
    self.channelSubscriptionBlocks[channel] = nil;
    self.openSubscriptions.remove(channel)
    self.pendingSubscriptions.remove(channel)
  }

  public func isSubscribedToChannel(channel:String) -> (Bool) {
    return self.openSubscriptions.contains(channel)
  }

  public func isTransportConnected() -> (Bool) {
    return self.transport!.isConnected()
  }
}


// MARK: Transport Delegate
extension FayeClient {
  public func didConnect() {
    self.connectionInitiated = false;
    self.handshake()
  }

  public func didDisconnect(error: NSError?) {
    self.delegate?.disconnectedFromServer(self)
    self.connectionInitiated = false
    self.fayeConnected = false
  }

  public func didFailConnection(error: NSError?) {
    self.delegate?.connectionFailed(self)
    self.connectionInitiated = false
    self.fayeConnected = false
  }

  public func didWriteError(error: NSError?) {
    self.delegate?.fayeClientError(self, error: error ?? NSError(error: .TransportWrite))
  }

  public func didReceiveMessage(text: String) {
    self.receive(text)
  }

}

// MARK: Private Bayuex Methods
private extension FayeClient {

  func parseFayeMessage(messageJSON:JSON) {
    let messageDict = messageJSON[0]
    if let channel = messageDict["channel"].string {

      // Handle Meta Channels
      if let metaChannel = BayeuxChannel(rawValue: channel) {
        switch(metaChannel) {
        case .Handshake:
          self.fayeClientId = messageDict["clientId"].stringValue
          if messageDict["successful"].int == 1 {
            self.delegate?.connectedToServer(self)
            self.fayeConnected = true;
            self.connect()
            self.subscribeQueuedSubscriptions()

          } else {
            // OOPS
          }
        case .Connect:
          if messageDict["successful"].int == 1 {
            self.fayeConnected = true;
            self.connect()
          } else {
            // OOPS
          }
        case .Disconnect:
          if messageDict["successful"].int == 1 {
            self.fayeConnected = false;
            self.transport?.closeConnection()
            self.delegate?.disconnectedFromServer(self)
          } else {
            // OOPS
          }
        case .Subscribe:
          if let success = messageJSON[0]["successful"].int where success == 1 {
            if let subscription = messageJSON[0]["subscription"].string {
              self.pendingSubscriptions.remove(subscription)
              self.openSubscriptions.insert(subscription)
              self.delegate?.didSubscribeToChannel(self, channel: subscription)
            } else {
              print("Missing subscription for Subscribe")
            }
          } else {
            // Subscribe Failed
            if let error = messageJSON[0]["error"].string {
              self.delegate?.subscriptionFailedWithError(self, error: error)
            }
          }
        case .Unsubscibe:
          if let subscription = messageJSON[0]["subscription"].string {
            self.openSubscriptions.remove(subscription)
            self.delegate?.didUnsubscribeFromChannel(self, channel: subscription)
          } else {
            print("Missing subscription for Unsubscribe")
          }
        }
      } else {
        // Handle Client Channel
        if self.isSubscribedToChannel(channel) {
          if messageJSON[0]["data"] != JSON.null {
            let data: AnyObject = messageJSON[0]["data"].object
            if let channelBlock = self.channelSubscriptionBlocks[channel] {
              channelBlock(data as! NSDictionary)
            } else {
              self.delegate?.messageReceived(self, messageDict: data as! NSDictionary, channel: channel)
            }
          } else {
            print("For some reason data is nil, maybe double posting?!")
          }
        } else {
          print("weird channel")
        }
      }
    } else {
      print("Missing channel")
    }
  }

  /**
   Bayeux messages
   */

  // Bayeux Handshake
  // "channel": "/meta/handshake",
  // "version": "1.0",
  // "minimumVersion": "1.0beta",
  // "supportedConnectionTypes": ["long-polling", "callback-polling", "iframe", "websocket]
  func handshake() {
    let connTypes:NSArray = ["long-polling", "callback-polling", "iframe", "websocket"]
    var dict = [String: AnyObject]()
    dict["channel"] = BayeuxChannel.Handshake.rawValue
    dict["version"] = "1.0"
    dict["minimumVersion"] = "1.0beta"
    dict["supportedConnectionTypes"] = connTypes

    if let string = JSON(dict).rawString() {
      self.transport?.writeString(string)
    }
  }

  // Bayeux Connect
  // "channel": "/meta/connect",
  // "clientId": "Un1q31d3nt1f13r",
  // "connectionType": "long-polling"
  func connect() {
    let dict:[String:AnyObject] = ["channel": BayeuxChannel.Connect.rawValue, "clientId": self.fayeClientId!, "connectionType": "websocket"]

    if let string = JSON(dict).rawString() {
      self.transport?.writeString(string)
    }
  }

  // Bayeux Disconnect
  // "channel": "/meta/disconnect",
  // "clientId": "Un1q31d3nt1f13r"
  func disconnect() {
    let dict:[String:AnyObject] = ["channel": BayeuxChannel.Disconnect.rawValue, "clientId": self.fayeClientId!, "connectionType": "websocket"]
    if let string = JSON(dict).rawString() {
      self.transport?.writeString(string)
    }
  }

  // Bayeux Subscribe
  // "channel": "/meta/subscribe",
  // "clientId": "Un1q31d3nt1f13r",
  // "subscription": "/foo/**"
  func subscribe(channel:String) {
    let dict:[String:AnyObject] = ["channel": BayeuxChannel.Subscribe.rawValue, "clientId": self.fayeClientId!, "subscription": channel]
    if let string = JSON(dict).rawString() {
      self.transport?.writeString(string)
      self.pendingSubscriptions.insert(channel)
    }
  }

  // Bayeux Unsubscribe
  // {
  // "channel": "/meta/unsubscribe",
  // "clientId": "Un1q31d3nt1f13r",
  // "subscription": "/foo/**"
  // }
  func unsubscribe(channel:String) {
    if let clientId = self.fayeClientId {
      let dict:[String:AnyObject] = ["channel": BayeuxChannel.Unsubscibe.rawValue, "clientId": clientId, "subscription": channel]
      if let string = JSON(dict).rawString() {
        self.transport?.writeString(string)
      }
    }
  }

  // Bayeux Publish
  // {
  // "channel": "/some/channel",
  // "clientId": "Un1q31d3nt1f13r",
  // "data": "some application string or JSON encoded object",
  // "id": "some unique message id"
  // }
  func publish(data:[String:AnyObject], channel:String) {
    if self.fayeConnected == true {
      let dict:[String:AnyObject] = ["channel": channel, "clientId": self.fayeClientId!, "id": self.nextMessageId(), "data": data]

      if let string = JSON(dict).rawString() {
        print("THIS IS THE PUBSLISH STRING: \(string)")
        self.transport?.writeString(string)
      }
    } else {
      // Faye is not connected
    }
  }
}

// MARK: Private Internal methods
private extension FayeClient {
  func subscribeQueuedSubscriptions() {
    // if there are any outstanding open subscriptions resubscribe
    for channel in self.queuedSubscriptions {
      self.subscribe(channel)
      self.queuedSubscriptions.remove(channel)
    }
  }

  func send(message: NSDictionary) {
    // Parse JSON
    if let string = JSON(message).rawString() {
      self.transport?.writeString(string)
    }
  }

  func receive(message: String) {
    // Parse JSON
    if let jsonData = message.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) {
      let json = JSON(data: jsonData)
      self.parseFayeMessage(json)
    }
  }

  func nextMessageId() -> String{
    self.messageNumber += 1
    if self.messageNumber >= UINT32_MAX {
      messageNumber = 0
    }
    return "\(self.messageNumber)".encodedString()
  }
}
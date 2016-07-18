//
//  FayeClient.swift
//  FayeSwift
//
//  Created by Haris Amin on 8/31/14.
//  Copyright (c) 2014 Haris Amin. All rights reserved.
//

import Foundation
import SwiftyJSON

// MARK: Subscription State
public enum FayeSubscriptionState {
    case Pending(FayeSubscriptionModel)
    case Subscribed(FayeSubscriptionModel)
    case Queued(FayeSubscriptionModel)
    case SubscribingTo(FayeSubscriptionModel)
    case Unknown(FayeSubscriptionModel?)
}

// MARK: BayuexChannel Messages
public enum BayeuxChannel: String {
    case Handshake = "/meta/handshake"
    case Connect = "/meta/connect"
    case Disconnect = "/meta/disconnect"
    case Subscribe = "/meta/subscribe"
    case Unsubscibe = "/meta/unsubscribe"
}

// MARK: Bayuex Parameters
public enum Bayeux: String {
    case Channel = "channel"
    case Version = "version"
    case ClientId = "clientId"
    case ConnectionType = "connectionType"
    case Data = "data"
    case Subscription = "subscription"
    case Id = "id"
    case MinimumVersion = "minimumVersion"
    case SupportedConnectionTypes = "supportedConnectionTypes"
    case Successful = "successful"
    case Error = "error"
}

// MARK: Bayuex Connection Type
public enum BayeuxConnection: String {
    case LongPolling = "long-polling"
    case Callback = "callback-polling"
    case iFrame = "iframe"
    case WebSocket = "websocket"
}

// MARK: Type Aliases
public typealias ChannelSubscriptionBlock = (NSDictionary) -> Void


// MARK: FayeClient
public class FayeClient : TransportDelegate {
  public var fayeURLString:String {
    didSet {
      if let transport = self.transport {
        transport.urlString = fayeURLString
      }
    }
  }
    
  public var fayeClientId:String?
  public weak var delegate:FayeClientDelegate?
  
  private var transport:WebsocketTransport?
  private var fayeConnected:Bool? {
    didSet {
      if fayeConnected == false {
        unsubscribeAllSubscriptions()
      }
    }
  }
  
  private var connectionInitiated:Bool?
  private var messageNumber:UInt32 = 0

  private var queuedSubscriptions = Array<FayeSubscriptionModel>()
  private var pendingSubscriptions = Array<FayeSubscriptionModel>()
  private var openSubscriptions = Array<FayeSubscriptionModel>()

  private var channelSubscriptionBlocks = Dictionary<String,ChannelSubscriptionBlock>()

  private lazy var pendingSubscriptionSchedule: NSTimer = {
        return NSTimer.scheduledTimerWithTimeInterval(
            45,
            target: self,
            selector: #selector(pendingSubscriptionsAction(_:)),
            userInfo: nil, 
            repeats: true
        )
    }()

  // MARK: Init
  public init(aFayeURLString:String, channel:String?) {
    self.fayeURLString = aFayeURLString
    self.fayeConnected = false;

    self.transport = WebsocketTransport(url: aFayeURLString)
    self.transport!.delegate = self;

    if let channel = channel {
      self.queuedSubscriptions.append(FayeSubscriptionModel(subscription: channel, clientId: fayeClientId))
    }
    
    self.connectionInitiated = false
  }

  public convenience init(aFayeURLString:String, channel:String, channelBlock:ChannelSubscriptionBlock) {
    self.init(aFayeURLString: aFayeURLString, channel: channel)
    self.channelSubscriptionBlocks[channel] = channelBlock;
  }
  
  deinit {
    pendingSubscriptionSchedule.invalidate()
  }
    
  public func connectToServer() {
    if self.connectionInitiated != true {
      self.transport?.openConnection()
      self.connectionInitiated = true;
    } else {
        print("Faye: Connection established")
    }
  }

  public func disconnectFromServer() {
    unsubscribeAllSubscriptions()
    
    self.disconnect()
  }

  public func sendMessage(messageDict: NSDictionary, channel:String) {
    self.publish(messageDict as! Dictionary, channel: channel)
  }

  public func sendMessage(messageDict:[String:AnyObject], channel:String) {
    self.publish(messageDict, channel: channel)
  }
    
  public func sendPing(data: NSData, completion: (() -> ())?) {
    self.transport?.sendPing(data, completion: completion)
  }

  public func subscribeToChannel(model:FayeSubscriptionModel, block:ChannelSubscriptionBlock?=nil) -> FayeSubscriptionState {
    guard !self.isSubscribedToChannel(model.subscription) else {
      return .Subscribed(model)
    }
    
    guard !self.pendingSubscriptions.contains({ $0 == model }) else {
      return .Pending(model)
    }
    
    if let block = block {
      self.channelSubscriptionBlocks[model.subscription] = block;
    }
    
    if self.fayeConnected == false {
      self.queuedSubscriptions.append(model)
        
      return .Queued(model)
    }
    
    self.subscribe(model)
    
    return .SubscribingTo(model)
  }
    
  public func subscribeToChannel(channel:String, block:ChannelSubscriptionBlock?=nil) -> FayeSubscriptionState {
    return subscribeToChannel(FayeSubscriptionModel(subscription: channel, clientId: fayeClientId), block: block)
  }
    
  public func unsubscribeFromChannel(channel:String) {
    removeChannelFromQueuedSubscriptions(channel)
    
    self.unsubscribe(channel)
    self.channelSubscriptionBlocks[channel] = nil;
    
    removeChannelFromOpenSubscriptions(channel)
    removeChannelFromPendingSubscriptions(channel)
  }

  public func isSubscribedToChannel(channel:String) -> Bool {
    return self.openSubscriptions.contains { $0.subscription == channel }
  }

  public func isTransportConnected() -> Bool {
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
    
  public func didReceivePong() {
    self.delegate?.pongReceived(self)
  }
}

// MARK: Private Bayuex Methods
private extension FayeClient {

  func parseFayeMessage(messageJSON:JSON) {
    let messageDict = messageJSON[0]
    if let channel = messageDict[Bayeux.Channel.rawValue].string {

      // Handle Meta Channels
      if let metaChannel = BayeuxChannel(rawValue: channel) {
        switch(metaChannel) {
        case .Handshake:
          self.fayeClientId = messageDict[Bayeux.ClientId.rawValue].stringValue
          if messageDict[Bayeux.Successful.rawValue].int == 1 {
            self.delegate?.connectedToServer(self)
            self.fayeConnected = true;
            self.connect()
            self.subscribeQueuedSubscriptions()
            pendingSubscriptionSchedule.valid
          } else {
            // OOPS
          }
        case .Connect:
          if messageDict[Bayeux.Successful.rawValue].int == 1 {
            self.fayeConnected = true;
            self.connect()
          } else {
            // OOPS
          }
        case .Disconnect:
          if messageDict[Bayeux.Successful.rawValue].int == 1 {
            self.fayeConnected = false;
            self.transport?.closeConnection()
            self.delegate?.disconnectedFromServer(self)
          } else {
            // OOPS
          }
        case .Subscribe:
          if let success = messageJSON[0][Bayeux.Successful.rawValue].int where success == 1 {
            if let subscription = messageJSON[0][Bayeux.Subscription.rawValue].string {
              removeChannelFromPendingSubscriptions(subscription)
              
              self.openSubscriptions.append(FayeSubscriptionModel(subscription: subscription, clientId: fayeClientId))
              self.delegate?.didSubscribeToChannel(self, channel: subscription)
            } else {
              print("Faye: Missing subscription for Subscribe")
            }
          } else {
            // Subscribe Failed
            if let error = messageJSON[0][Bayeux.Error.rawValue].string,
            subscription = messageJSON[0][Bayeux.Subscription.rawValue].string {
              removeChannelFromPendingSubscriptions(subscription)
                
              self.delegate?.subscriptionFailedWithError(
                self,
                error: subscriptionError.error(subscription: subscription, error: error)
              )
            }
          }
        case .Unsubscibe:
          if let subscription = messageJSON[0][Bayeux.Subscription.rawValue].string {
            removeChannelFromOpenSubscriptions(subscription)
            self.delegate?.didUnsubscribeFromChannel(self, channel: subscription)
          } else {
            print("Faye: Missing subscription for Unsubscribe")
          }
        }
      } else {
        // Handle Client Channel
        if self.isSubscribedToChannel(channel) {
          if messageJSON[0][Bayeux.Data.rawValue] != JSON.null {
            let data: AnyObject = messageJSON[0][Bayeux.Data.rawValue].object
            
            if let channelBlock = self.channelSubscriptionBlocks[channel] {
              channelBlock(data as! NSDictionary)
            } else {
                print("Faye: Failed to get channel block for : \(channel)")
            }
            
            self.delegate?.messageReceived(
              self,
              messageDict: data as! NSDictionary,
              channel: channel
            )
          } else {
            print("Faye: For some reason data is nil for channel: \(channel)")
          }
        } else {
          print("Faye: Weird channel that not been set to subscribed: \(channel)")
        }
      }
    } else {
      print("Faye: Missing channel for \(messageDict)")
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
    let connTypes:NSArray = [BayeuxConnection.LongPolling.rawValue, BayeuxConnection.Callback.rawValue, BayeuxConnection.iFrame.rawValue, BayeuxConnection.WebSocket.rawValue]
    
    var dict = [String: AnyObject]()
    dict[Bayeux.Channel.rawValue] = BayeuxChannel.Handshake.rawValue
    dict[Bayeux.Version.rawValue] = "1.0"
    dict[Bayeux.MinimumVersion.rawValue] = "1.0beta"
    dict[Bayeux.SupportedConnectionTypes.rawValue] = connTypes

    if let string = JSON(dict).rawString() {
      self.transport?.writeString(string)
    }
  }

  // Bayeux Connect
  // "channel": "/meta/connect",
  // "clientId": "Un1q31d3nt1f13r",
  // "connectionType": "long-polling"
  func connect() {
    let dict:[String:AnyObject] = [Bayeux.Channel.rawValue: BayeuxChannel.Connect.rawValue, Bayeux.ClientId.rawValue: self.fayeClientId!, Bayeux.ConnectionType.rawValue: BayeuxConnection.WebSocket.rawValue, "advice": ["timeout": 0]]

    if let string = JSON(dict).rawString() {
      self.transport?.writeString(string)
    }
  }

  // Bayeux Disconnect
  // "channel": "/meta/disconnect",
  // "clientId": "Un1q31d3nt1f13r"
  func disconnect() {
    let dict:[String:AnyObject] = [Bayeux.Channel.rawValue: BayeuxChannel.Disconnect.rawValue, Bayeux.ClientId.rawValue: self.fayeClientId!, Bayeux.ConnectionType.rawValue: BayeuxConnection.WebSocket.rawValue]
    if let string = JSON(dict).rawString() {
      self.transport?.writeString(string)
    }
  }

  // Bayeux Subscribe
  // "channel": "/meta/subscribe",
  // "clientId": "Un1q31d3nt1f13r",
  // "subscription": "/foo/**"
  func subscribe(var model:FayeSubscriptionModel) {
    do {
        let json = try model.jsonString()
        
        self.transport?.writeString(json)
        self.pendingSubscriptions.append(model)
    } catch FayeSubscriptionModelError.ConversationError {
        
    } catch FayeSubscriptionModelError.ClientIdNotValid where fayeClientId?.characters.count > 0 {
        model.clientId = fayeClientId
        subscribe(model)
    } catch {
        
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
      let dict:[String:AnyObject] = [Bayeux.Channel.rawValue: BayeuxChannel.Unsubscibe.rawValue, Bayeux.ClientId.rawValue: clientId, Bayeux.Subscription.rawValue: channel]
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
      let dict:[String:AnyObject] = [Bayeux.Channel.rawValue: channel, Bayeux.ClientId.rawValue: self.fayeClientId!, Bayeux.Id.rawValue: self.nextMessageId(), Bayeux.Data.rawValue: data]

      if let string = JSON(dict).rawString() {
        print("Faye: Publish string: \(string)")
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
      removeChannelFromQueuedSubscriptions(channel.subscription)
      subscribeToChannel(channel)
    }
  }

  func resubscribeToPendingSubscriptions() {
    print("Faye: Resubscribing to all pending(\(pendingSubscriptions.count)) subscriptions")
    
    for channel in pendingSubscriptions {
      removeChannelFromPendingSubscriptions(channel.subscription)
      subscribeToChannel(channel)
    }
  }
    
  func unsubscribeAllSubscriptions() {
    let all = queuedSubscriptions + openSubscriptions + pendingSubscriptions
    
    all.forEach({ unsubscribeFromChannel($0.subscription) })
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

  func nextMessageId() -> String {
    self.messageNumber += 1
    
    if self.messageNumber >= UINT32_MAX {
      messageNumber = 0
    }
    
    return "\(self.messageNumber)".encodedString()
  }

  // MARK:
  // MARK: Subscriptions
  
  private func removeChannelFromQueuedSubscriptions(channel: String) -> Bool {
    let index = self.queuedSubscriptions.indexOf { $0.subscription == channel }
    
    if let index = index {
      self.queuedSubscriptions.removeAtIndex(index)
        
      return true
    }
    
    return false
  }

  private func removeChannelFromPendingSubscriptions(channel: String) -> Bool {
    let index = self.pendingSubscriptions.indexOf { $0.subscription == channel }
    
    if let index = index {
      self.pendingSubscriptions.removeAtIndex(index)
        
      return true
    }
    
    return false
  }

  private func removeChannelFromOpenSubscriptions(channel: String) -> Bool {
    let index = self.openSubscriptions.indexOf { $0.subscription == channel }
    
    if let index = index {
      self.openSubscriptions.removeAtIndex(index)
        
      return true
    }
    
    return false
  }
    
  // MARK: Private - Timer Action
  @objc
  func pendingSubscriptionsAction(timer: NSTimer) {
    guard fayeConnected == true else {
      print("Faye: Failed to resubscribe to all pending channels, socket disconnected")
      
      return
    }
    
    resubscribeToPendingSubscriptions()
  }
}

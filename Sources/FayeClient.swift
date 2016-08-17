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
  
  var transport:WebsocketTransport?
  
  public internal(set) var fayeConnected:Bool? {
    didSet {
      if fayeConnected == false {
        unsubscribeAllSubscriptions()
      }
    }
  }
  
  var connectionInitiated:Bool?
  var messageNumber:UInt32 = 0

  var queuedSubscriptions = Array<FayeSubscriptionModel>()
  var pendingSubscriptions = Array<FayeSubscriptionModel>()
  var openSubscriptions = Array<FayeSubscriptionModel>()

  var channelSubscriptionBlocks = Dictionary<String, ChannelSubscriptionBlock>()

  lazy var pendingSubscriptionSchedule: NSTimer = {
        return NSTimer.scheduledTimerWithTimeInterval(
            45,
            target: self,
            selector: #selector(pendingSubscriptionsAction(_:)),
            userInfo: nil, 
            repeats: true
        )
    }()

  /// Default in 10 seconds
  let timeOut: Int

  let readOperationQueue = dispatch_queue_create("com.hamin.fayeclient.read", DISPATCH_QUEUE_SERIAL)
  let writeOperationQueue = dispatch_queue_create("com.hamin.fayeclient.write", DISPATCH_QUEUE_CONCURRENT)
    
  // MARK: Init
  public init(aFayeURLString:String, channel:String?, timeoutAdvice:Int=10000) {
    self.fayeURLString = aFayeURLString
    self.fayeConnected = false;
    self.timeOut = timeoutAdvice
    
    self.transport = WebsocketTransport(url: aFayeURLString)
    self.transport!.delegate = self;

    if let channel = channel {
      self.queuedSubscriptions.append(FayeSubscriptionModel(subscription: channel, clientId: fayeClientId))
    }
  }

  public convenience init(aFayeURLString:String, channel:String, channelBlock:ChannelSubscriptionBlock) {
    self.init(aFayeURLString: aFayeURLString, channel: channel)
    self.channelSubscriptionBlocks[channel] = channelBlock;
  }
  
  deinit {
    pendingSubscriptionSchedule.invalidate()
  }

  // MARK: Client
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
    dispatch_async(writeOperationQueue) { [unowned self] in
      self.transport?.sendPing(data, completion: completion)
    }
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
    return subscribeToChannel(
        FayeSubscriptionModel(subscription: channel, clientId: fayeClientId),
        block: block
    )
  }
    
  public func unsubscribeFromChannel(channel:String) {
    removeChannelFromQueuedSubscriptions(channel)
    
    self.unsubscribe(channel)
    self.channelSubscriptionBlocks[channel] = nil;
    
    removeChannelFromOpenSubscriptions(channel)
    removeChannelFromPendingSubscriptions(channel)
  }
}

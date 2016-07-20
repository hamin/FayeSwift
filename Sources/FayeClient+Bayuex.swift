//
//  FayeClient+Bayuex.swift
//  Pods
//
//  Created by Shams Ahmed on 19/07/2016.
//
//

import Foundation
import SwiftyJSON

// MARK: Bayuex Connection Type
public enum BayeuxConnection: String {
    case LongPolling = "long-polling"
    case Callback = "callback-polling"
    case iFrame = "iframe"
    case WebSocket = "websocket"
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

// MARK: Private Bayuex Methods
extension FayeClient {
    
    /**
     Bayeux messages
     */
    
    // Bayeux Handshake
    // "channel": "/meta/handshake",
    // "version": "1.0",
    // "minimumVersion": "1.0beta",
    // "supportedConnectionTypes": ["long-polling", "callback-polling", "iframe", "websocket]
    func handshake() {
        dispatch_sync(writeOperationQueue) { [unowned self] in
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
    }
    
    // Bayeux Connect
    // "channel": "/meta/connect",
    // "clientId": "Un1q31d3nt1f13r",
    // "connectionType": "long-polling"
    func connect() {
        dispatch_sync(writeOperationQueue) { [unowned self] in
            let dict:[String:AnyObject] = [Bayeux.Channel.rawValue: BayeuxChannel.Connect.rawValue, Bayeux.ClientId.rawValue: self.fayeClientId!, Bayeux.ConnectionType.rawValue: BayeuxConnection.WebSocket.rawValue, "advice": ["timeout": 0]]
            
            if let string = JSON(dict).rawString() {
                self.transport?.writeString(string)
            }
        }
    }
    
    // Bayeux Disconnect
    // "channel": "/meta/disconnect",
    // "clientId": "Un1q31d3nt1f13r"
    func disconnect() {
        dispatch_sync(writeOperationQueue) { [unowned self] in
            let dict:[String:AnyObject] = [Bayeux.Channel.rawValue: BayeuxChannel.Disconnect.rawValue, Bayeux.ClientId.rawValue: self.fayeClientId!, Bayeux.ConnectionType.rawValue: BayeuxConnection.WebSocket.rawValue]
            if let string = JSON(dict).rawString() {
                self.transport?.writeString(string)
            }
        }
    }
    
    // Bayeux Subscribe
    // "channel": "/meta/subscribe",
    // "clientId": "Un1q31d3nt1f13r",
    // "subscription": "/foo/**"
    func subscribe(var model:FayeSubscriptionModel) {
        dispatch_async(writeOperationQueue) { [unowned self] in
            do {
                let json = try model.jsonString()
                
                self.transport?.writeString(json)
                self.pendingSubscriptions.append(model)
            } catch FayeSubscriptionModelError.ConversationError {
                
            } catch FayeSubscriptionModelError.ClientIdNotValid
                where self.fayeClientId?.characters.count > 0 {
                    model.clientId = self.fayeClientId
                    self.subscribe(model)
            } catch {
                
            }
        }
    }
    
    // Bayeux Unsubscribe
    // {
    // "channel": "/meta/unsubscribe",
    // "clientId": "Un1q31d3nt1f13r",
    // "subscription": "/foo/**"
    // }
    func unsubscribe(channel:String) {
        dispatch_sync(writeOperationQueue) { [unowned self] in
            if let clientId = self.fayeClientId {
                let dict:[String:AnyObject] = [Bayeux.Channel.rawValue: BayeuxChannel.Unsubscibe.rawValue, Bayeux.ClientId.rawValue: clientId, Bayeux.Subscription.rawValue: channel]
                
                if let string = JSON(dict).rawString() {
                    self.transport?.writeString(string)
                }
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
        dispatch_async(writeOperationQueue) { [weak self] in
            if let clientId = self?.fayeClientId, messageId = self?.nextMessageId()
                where self?.fayeConnected == true {
                let dict:[String:AnyObject] = [
                    Bayeux.Channel.rawValue: channel,
                    Bayeux.ClientId.rawValue: clientId,
                    Bayeux.Id.rawValue: messageId,
                    Bayeux.Data.rawValue: data
                ]
                
                if let string = JSON(dict).rawString() {
                    print("Faye: Publish string: \(string)")
                    self?.transport?.writeString(string)
                }
            }
        }
    }
}

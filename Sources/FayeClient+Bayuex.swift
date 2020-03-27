//
//  FayeClient+Bayuex.swift
//  Pods
//
//  Created by Shams Ahmed on 19/07/2016.
//
//

import Foundation


// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


// MARK: Bayuex Connection Type
public enum BayeuxConnection: String {
    case LongPolling = "long-polling"
    case Callback = "callback-polling"
    case iFrame = "iframe"
    case WebSocket = "websocket"
}

// MARK: BayuexChannel Messages
public enum BayeuxChannel: String, Encodable, Equatable{
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
    case Advice = "advice"
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
        writeOperationQueue.sync { [unowned self] in
            let connTypes = [BayeuxConnection.LongPolling.rawValue,
                             BayeuxConnection.Callback.rawValue,
                             BayeuxConnection.iFrame.rawValue,
                             BayeuxConnection.WebSocket.rawValue]
            
            var dict = [String: AnyObject]()
            dict[Bayeux.Channel.rawValue] = BayeuxChannel.Handshake.rawValue as AnyObject?
            dict[Bayeux.Version.rawValue] = "1.0" as AnyObject?
            dict[Bayeux.MinimumVersion.rawValue] = "1.0beta" as AnyObject?
            dict[Bayeux.SupportedConnectionTypes.rawValue] = connTypes as? AnyObject
            send(dict)
        }
    }
    
    // Bayeux Connect
    // "channel": "/meta/connect",
    // "clientId": "Un1q31d3nt1f13r",
    // "connectionType": "long-polling"
    func connect() {
        writeOperationQueue.sync { [unowned self] in
            let dict:[String:AnyObject] = [
                Bayeux.Channel.rawValue: BayeuxChannel.Connect.rawValue as AnyObject,
                Bayeux.ClientId.rawValue: self.fayeClientId! as AnyObject,
                Bayeux.ConnectionType.rawValue: BayeuxConnection.WebSocket.rawValue as AnyObject,
                Bayeux.Advice.rawValue: ["timeout": self.timeOut] as AnyObject
            ]
            send(dict)
        }
    }
    
    // Bayeux Disconnect
    // "channel": "/meta/disconnect",
    // "clientId": "Un1q31d3nt1f13r"
    func disconnect() {
        writeOperationQueue.sync { [unowned self] in
            guard let clientId = self.fayeClientId else { return }
            let dict:[String:AnyObject] = [Bayeux.Channel.rawValue: BayeuxChannel.Disconnect.rawValue as AnyObject,
                                           Bayeux.ClientId.rawValue: clientId as AnyObject,
                                           Bayeux.ConnectionType.rawValue: BayeuxConnection.WebSocket.rawValue as AnyObject]

            send(dict)
        }
    }

    // Bayeux Subscribe
    // "channel": "/meta/subscribe",
    // "clientId": "Un1q31d3nt1f13r",
    // "subscription": "/foo/**"
    func subscribe(_ model:FayeSubscriptionModel) {
        writeOperationQueue.sync { [unowned self] in
            do {
                var newModel = model
                if newModel.clientId == nil { newModel.clientId = self.fayeClientId }
                let json = try JSONEncoder().encode(newModel)
                guard let string = String(data: json, encoding: .utf8) else { return }
                
                self.transport?.writeString(string)
                self.pendingSubscriptions.append(model)

            } catch {
                // TODO: catch this error
            }
        }
    }
    
    // Bayeux Unsubscribe
    // {
    // "channel": "/meta/unsubscribe",
    // "clientId": "Un1q31d3nt1f13r",
    // "subscription": "/foo/**"
    // }
    func unsubscribe(_ channel:String) {
        writeOperationQueue.sync { [unowned self] in
            guard let clientId = self.fayeClientId else { return }
            let dict:[String:AnyObject] = [Bayeux.Channel.rawValue: BayeuxChannel.Unsubscibe.rawValue as AnyObject,
                                           Bayeux.ClientId.rawValue: clientId as AnyObject,
                                           Bayeux.Subscription.rawValue: channel as AnyObject]
            send(dict)
        }
    }
    
    // Bayeux Publish
    // {
    // "channel": "/some/channel",
    // "clientId": "Un1q31d3nt1f13r",
    // "data": "some application string or JSON encoded object",
    // "id": "some unique message id"
    // }
    func publish(_ data:[String:AnyObject], channel:String) {
        writeOperationQueue.sync { [weak self] in
            if let clientId = self?.fayeClientId, let messageId = self?.nextMessageId(), self?.fayeConnected == true {
                let dict:[String:AnyObject] = [Bayeux.Channel.rawValue: channel as AnyObject,
                                               Bayeux.ClientId.rawValue: clientId as AnyObject,
                                               Bayeux.Id.rawValue: messageId as AnyObject,
                                               Bayeux.Data.rawValue: data as AnyObject]
                
                send(dict)
            }
        }
    }
}

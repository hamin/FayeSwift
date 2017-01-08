//
//  FayeClient+Parsing.swift
//  Pods
//
//  Created by Shams Ahmed on 19/07/2016.
//
//

import Foundation
import SwiftyJSON

extension FayeClient {
   
    // MARK:
    // MARK: Parsing

    func parseFayeMessage(_ messageJSON:JSON) {
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
                        _ = pendingSubscriptionSchedule.isValid
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
                    if let success = messageJSON[0][Bayeux.Successful.rawValue].int, success == 1 {
                        if let subscription = messageJSON[0][Bayeux.Subscription.rawValue].string {
                            _ = removeChannelFromPendingSubscriptions(subscription)
                            
                            self.openSubscriptions.append(FayeSubscriptionModel(subscription: subscription, clientId: fayeClientId))
                            self.delegate?.didSubscribeToChannel(self, channel: subscription)
                        } else {
                            print("Faye: Missing subscription for Subscribe")
                        }
                    } else {
                        // Subscribe Failed
                        if let error = messageJSON[0][Bayeux.Error.rawValue].string,
                            let subscription = messageJSON[0][Bayeux.Subscription.rawValue].string {
                            _ = removeChannelFromPendingSubscriptions(subscription)
                            
                            self.delegate?.subscriptionFailedWithError(
                                self,
                                error: subscriptionError.error(subscription: subscription, error: error)
                            )
                        }
                    }
                case .Unsubscibe:
                    if let subscription = messageJSON[0][Bayeux.Subscription.rawValue].string {
                        _ = removeChannelFromOpenSubscriptions(subscription)
                        self.delegate?.didUnsubscribeFromChannel(self, channel: subscription)
                    } else {
                        print("Faye: Missing subscription for Unsubscribe")
                    }
                }
            } else {
                // Handle Client Channel
                if self.isSubscribedToChannel(channel) {
                    if messageJSON[0][Bayeux.Data.rawValue] != JSON.null {
                        let data: AnyObject = messageJSON[0][Bayeux.Data.rawValue].object as AnyObject
                        
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
}

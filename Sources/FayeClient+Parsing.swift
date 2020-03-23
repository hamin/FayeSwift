//
//  FayeClient+Parsing.swift
//  Pods
//
//  Created by Shams Ahmed on 19/07/2016.
//
//

import Foundation

extension FayeClient {

    // MARK: Parsing
    func parseFayeJsonDictionaryMessage(_ message: [String: Any]) {
        let messageDict = message
        if let channel = messageDict[Bayeux.Channel.rawValue] as? String {

            // Handle Meta Channels
            if let metaChannel = BayeuxChannel(rawValue: channel) {
                switch(metaChannel) {
                case .Handshake:
                    self.fayeClientId = messageDict[Bayeux.ClientId.rawValue] as? String
                    if (messageDict[Bayeux.Successful.rawValue] as? Int) == 1 {
                        self.delegate?.connectedToServer(self)
                        self.fayeConnected = true;
                        self.connect()
                        self.subscribeQueuedSubscriptions()
                        _ = pendingSubscriptionSchedule.isValid
                    } else {
                        // OOPS
                    }
                case .Connect:
                    if (messageDict[Bayeux.Successful.rawValue] as? Int) == 1 {
                        self.fayeConnected = true;
                        self.connect()
                    } else {
                        // OOPS
                    }
                case .Disconnect:
                    if (messageDict[Bayeux.Successful.rawValue] as? Int) == 1 {
                        self.fayeConnected = false;
                        self.transport?.closeConnection()
                        self.delegate?.disconnectedFromServer(self)
                    } else {
                        // OOPS
                    }
                case .Subscribe:
                    if let success = messageDict[Bayeux.Successful.rawValue] as? Int, success == 1 {
                        if let subscription = messageDict[Bayeux.Subscription.rawValue] as? String {
                            _ = removeChannelFromPendingSubscriptions(subscription)

                            self.openSubscriptions.append(FayeSubscriptionModel(subscription: subscription, channel: .Subscribe, clientId: fayeClientId))
                            self.delegate?.didSubscribeToChannel(self, channel: subscription)
                        } else {
                            print("Faye: Missing subscription for Subscribe")
                        }
                    } else {
                        // Subscribe Failed
                        if let error = messageDict[Bayeux.Error.rawValue] as? String,
                            let subscription = messageDict[Bayeux.Subscription.rawValue] as? String {
                            _ = removeChannelFromPendingSubscriptions(subscription)

                            self.delegate?.subscriptionFailedWithError(
                                self,
                                error: subscriptionError.error(subscription: subscription, error: error)
                            )
                        }
                    }
                case .Unsubscibe:
                    if let subscription = messageDict[Bayeux.Subscription.rawValue] as? String {
                        _ = removeChannelFromOpenSubscriptions(subscription)
                        self.delegate?.didUnsubscribeFromChannel(self, channel: subscription)
                    } else {
                        print("Faye: Missing subscription for Unsubscribe")
                    }
                }
            } else {
                // Handle Client Channel
                handleMessageReceived(messageDict, channel: channel)
            }
        } else {
            print("Faye: Missing channel for \(messageDict)")
        }
    }

    private func handleMessageReceived(_ messageDict: [String: Any], channel: String) {
        // Handle Client Channel
        if self.isSubscribedToChannel(channel) {
            if messageDict[Bayeux.Data.rawValue] != nil {
                let data = messageDict[Bayeux.Data.rawValue] as AnyObject

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
}

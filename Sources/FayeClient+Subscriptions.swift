//
//  FayeClient+Subscriptions.swift
//  Pods
//
//  Created by Shams Ahmed on 19/07/2016.
//
//

import Foundation
import SwiftyJSON

// MARK: Private Internal methods
extension FayeClient {
    
    func subscribeQueuedSubscriptions() {
        // if there are any outstanding open subscriptions resubscribe
        for channel in self.queuedSubscriptions {
            removeChannelFromQueuedSubscriptions(channel.subscription)
            subscribeToChannel(channel)
        }
    }
    
    func resubscribeToPendingSubscriptions() {
        if !pendingSubscriptions.isEmpty {
            print("Faye: Resubscribing to \(pendingSubscriptions.count) pending subscriptions")
            
            for channel in pendingSubscriptions {
                removeChannelFromPendingSubscriptions(channel.subscription)
                subscribeToChannel(channel)
            }
        }
    }
    
    func unsubscribeAllSubscriptions() {
        let all = queuedSubscriptions + openSubscriptions + pendingSubscriptions
        
        all.forEach({ unsubscribeFromChannel($0.subscription) })
    }
    
    // MARK:
    // MARK: Send/Receive

    func send(_ message: NSDictionary) {
        writeOperationQueue.async { [unowned self] in
            if let string = JSON(message).rawString() {
                self.transport?.writeString(string)
            }
        }
    }
    
    func receive(_ message: String) {
        readOperationQueue.sync { [unowned self] in
            if let jsonData = message.data(using: String.Encoding.utf8, allowLossyConversion: false) {
                let json = JSON(data: jsonData)
                
                self.parseFayeMessage(json)
            }
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
    
    func removeChannelFromQueuedSubscriptions(_ channel: String) -> Bool {
        objc_sync_enter(self.queuedSubscriptions)
        defer { objc_sync_exit(self.queuedSubscriptions) }
        
        let index = self.queuedSubscriptions.index { $0.subscription == channel }
        
        if let index = index {
            self.queuedSubscriptions.remove(at: index)
            
            return true
        }
        
        return false
    }
    
    func removeChannelFromPendingSubscriptions(_ channel: String) -> Bool {
        objc_sync_enter(self.pendingSubscriptions)
        defer { objc_sync_exit(self.pendingSubscriptions) }
        
        let index = self.pendingSubscriptions.index { $0.subscription == channel }
        
        if let index = index {
            self.pendingSubscriptions.remove(at: index)
            
            return true
        }
        
        return false
    }
    
    func removeChannelFromOpenSubscriptions(_ channel: String) -> Bool {
        objc_sync_enter(self.pendingSubscriptions)
        defer { objc_sync_exit(self.pendingSubscriptions) }
        
        let index = self.openSubscriptions.index { $0.subscription == channel }
        
        if let index = index {
            self.openSubscriptions.remove(at: index)
            
            return true
        }
        
        return false
    }
}

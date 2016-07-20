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
    
    // MARK:
    // MARK: Send/Receive

    func send(message: NSDictionary) {
        dispatch_async(writeOperationQueue) { [unowned self] in
            if let string = JSON(message).rawString() {
                self.transport?.writeString(string)
            }
        }
    }
    
    func receive(message: String) {
        dispatch_sync(readOperationQueue) { [unowned self] in
            if let jsonData = message.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) {
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
    
    func removeChannelFromQueuedSubscriptions(channel: String) -> Bool {
        objc_sync_enter(self.queuedSubscriptions)
        defer { objc_sync_exit(self.queuedSubscriptions) }
        
        let index = self.queuedSubscriptions.indexOf { $0.subscription == channel }
        
        if let index = index {
            self.queuedSubscriptions.removeAtIndex(index)
            
            return true
        }
        
        return false
    }
    
    func removeChannelFromPendingSubscriptions(channel: String) -> Bool {
        objc_sync_enter(self.pendingSubscriptions)
        defer { objc_sync_exit(self.pendingSubscriptions) }
        
        let index = self.pendingSubscriptions.indexOf { $0.subscription == channel }
        
        if let index = index {
            self.pendingSubscriptions.removeAtIndex(index)
            
            return true
        }
        
        return false
    }
    
    func removeChannelFromOpenSubscriptions(channel: String) -> Bool {
        objc_sync_enter(self.pendingSubscriptions)
        defer { objc_sync_exit(self.pendingSubscriptions) }
        
        let index = self.openSubscriptions.indexOf { $0.subscription == channel }
        
        if let index = index {
            self.openSubscriptions.removeAtIndex(index)
            
            return true
        }
        
        return false
    }
}

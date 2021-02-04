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
            _ = removeChannelFromQueuedSubscriptions(channel.subscription)
            _ = subscribeToChannel(channel)
        }
    }
    
    func resubscribeToPendingSubscriptions() {
        if !pendingSubscriptions.isEmpty {
            print("Faye: Resubscribing to \(pendingSubscriptions.count) pending subscriptions")
            
            for channel in pendingSubscriptions {
                _ = removeChannelFromPendingSubscriptions(channel.subscription)
                _ = subscribeToChannel(channel)
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
                do {
                    let json = try JSON(data: jsonData)
                    self.parseFayeMessage(json)
                } catch {
                    print(error)
                }
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
        var result = false
        queuedSubsLockQueue.sync {
            let index = self.queuedSubscriptions.firstIndex { $0.subscription == channel }
            
            if let index = index {
                self.queuedSubscriptions.remove(at: index)
                
                result = true;
            }
        }
        
        return result
    }
    
    func removeChannelFromPendingSubscriptions(_ channel: String) -> Bool {
        var result = false
        pendingSubsLockQueue.sync {
            let index = self.pendingSubscriptions.firstIndex { $0.subscription == channel }
            
            if let index = index {
                self.pendingSubscriptions.remove(at: index)
                
                result = true
            }
        }
        
        return result
    }
    
    func removeChannelFromOpenSubscriptions(_ channel: String) -> Bool {
        var result = false
        openSubsLockQueue.sync {
            let index = self.openSubscriptions.firstIndex { $0.subscription == channel }
            
            if let index = index {
                self.openSubscriptions.remove(at: index)
                
                result = true
            }
        }
        
        return result
    }
}

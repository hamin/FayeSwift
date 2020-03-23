//
//  FayeClient+Subscriptions.swift
//  Pods
//
//  Created by Shams Ahmed on 19/07/2016.
//
//

import Foundation

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

    func send(_ message: [String: Any]) {
        writeOperationQueue.async { [unowned self] in
            if let data = try? JSONSerialization.data(withJSONObject: message, options: .prettyPrinted),
                let string = String(data: data, encoding: .utf8) {
                self.transport?.writeString(string)
            }
        }
    }
    
    func receive(_ message: String) {
        readOperationQueue.sync { [unowned self] in
            do {
                let jsonData = Data(message.utf8)
                let jsonDictArray = try JSONSerialization.jsonObject(with: jsonData, options: .fragmentsAllowed) as? [Any]
                guard let jsonDict = jsonDictArray?.first as? [String: Any] else { return }
                parseFayeJsonDictionaryMessage(jsonDict)
            } catch {
                // TODO: Add an error here to forward on for failed to decode
            }
        }
    }

    func receive(_ data: Data) {
        readOperationQueue.sync { [unowned self] in
            do {
                let jsonDictArray = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [Any]
                guard let jsonDict = jsonDictArray?.first as? [String: Any] else { return }
                parseFayeJsonDictionaryMessage(jsonDict)
            } catch {
                // TODO: Add an error here to forward on for failed to decode
            }
        }
    }
    
    func nextMessageId() -> String {
        self.messageNumber += 1
        
        if self.messageNumber >= UINT32_MAX {
            messageNumber = 0
        }
        
        return "\(self.messageNumber)".encodeToBase64()
    }
    
    // MARK: Subscriptions
    
    func removeChannelFromQueuedSubscriptions(_ channel: String) -> Bool {
        var result = false
        queuedSubsLockQueue.sync {
            let index = self.queuedSubscriptions.index { $0.subscription == channel }
            
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
            let index = self.pendingSubscriptions.index { $0.subscription == channel }
            
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
            let index = self.openSubscriptions.index { $0.subscription == channel }
            
            if let index = index {
                self.openSubscriptions.remove(at: index)
                
                result = true
            }
        }
        
        return result
    }
}

extension String {
    func encodeToBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }
}

//
//  FayeClient+Action.swift
//  Pods
//
//  Created by Shams Ahmed on 19/07/2016.
//
//

import Foundation

extension FayeClient {
    
    // MARK: Private - Timer Action
    @objc
    func pendingSubscriptionsAction(_ timer: Timer) {
        guard fayeConnected == true else {
            print("Faye: Failed to resubscribe to all pending channels, socket disconnected")
            
            return
        }
        
        resubscribeToPendingSubscriptions()
    }
}

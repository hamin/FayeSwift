//
//  FayeClient+Helper.swift
//  Pods
//
//  Created by Shams Ahmed on 19/07/2016.
//
//

import Foundation

extension FayeClient {
    
    // MARK: Helper
    public func isSubscribedToChannel(channel:String) -> Bool {
        return self.openSubscriptions.contains { $0.subscription == channel }
    }
    
    public func isTransportConnected() -> Bool {
        return self.transport!.isConnected()
    }
}

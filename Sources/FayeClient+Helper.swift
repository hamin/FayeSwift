//
//  FayeClient+Helper.swift
//  Pods
//
//  Created by Shams Ahmed on 19/07/2016.
//
//

import Foundation

public extension FayeClient {
    
    // MARK: Helper
    
    ///  Validate whatever a subscription has been subscribed correctly 
    public func isSubscribedToChannel(_ channel:String) -> Bool {
        return self.openSubscriptions.contains { $0.subscription == channel }
    }
    
    ///  Validate faye transport is connected
    public func isTransportConnected() -> Bool {
        return self.transport?.isConnected ?? false
    }
}

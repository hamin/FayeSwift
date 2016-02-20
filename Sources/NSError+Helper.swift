//
//  NSError+Helper.swift
//  Pods
//
//  Created by Shams Ahmed on 17/02/2016.
//
//

import Foundation

public enum FayeSocketError {
    case LostConnection, TransportWrite
}

public extension NSError {
    // MARK:
    // MARK: Error
    
    /// Helper to create a error object for faye realted issues
    convenience init(error: FayeSocketError) {
        self.init(domain: "", code: 10000, userInfo: nil)
    }
}

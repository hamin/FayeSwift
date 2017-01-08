//
//  FayeSubscriptionModel.swift
//  Pods
//
//  Created by Shams Ahmed on 25/04/2016.
//
//

import Foundation
import SwiftyJSON

public enum FayeSubscriptionModelError: Error {
    case conversationError
    case clientIdNotValid
}

// MARK:
// MARK: FayeSubscriptionModel

///  Subscription Model
open class FayeSubscriptionModel {
    
    /// Subscription URL
    open let subscription: String
    
    /// Channel type for request
    open let channel: BayeuxChannel
    
    /// Uniqle client id for socket
    open var clientId: String?
    
    /// Model must conform to Hashable
    open var hashValue: Int {
        return subscription.hashValue
    }
    
    // MARK:
    // MARK: Init
    
    public init(subscription: String, channel: BayeuxChannel=BayeuxChannel.Subscribe, clientId: String?) {
        self.subscription = subscription
        self.channel = channel
        self.clientId = clientId
    }
    
    // MARK:
    // MARK: JSON
    
    ///  Return Json string from model
    open func jsonString() throws -> String {
        do {
            guard let model = try JSON(toDictionary()).rawString() else {
                throw FayeSubscriptionModelError.conversationError
            }
            
            return model
        } catch {
            throw FayeSubscriptionModelError.clientIdNotValid
        }
    }
    
    // MARK:
    // MARK: Helper
    
    ///  Create dictionary of model object, Subclasses should override method to return custom model
    open func toDictionary() throws -> [String: AnyObject] {
        guard let clientId = clientId else {
            throw FayeSubscriptionModelError.clientIdNotValid
        }
        
        return [Bayeux.Channel.rawValue: channel.rawValue as AnyObject,
                Bayeux.ClientId.rawValue: clientId as AnyObject,
                Bayeux.Subscription.rawValue: subscription as AnyObject]
    }
}

// MARK: 
// MARK: Description

extension FayeSubscriptionModel: CustomStringConvertible {
    
    public var description: String {
        return "FayeSubscriptionModel: \(try? self.toDictionary())"
    }
}

// MARK:
// MARK: Equatable

public func ==(lhs: FayeSubscriptionModel, rhs: FayeSubscriptionModel) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

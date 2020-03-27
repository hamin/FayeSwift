//
//  FayeSubscriptionModel.swift
//  Pods
//
//  Created by Shams Ahmed on 25/04/2016.
//
//

import Foundation

public struct FayeSubscriptionModel: Encodable, Equatable {

    /// Subscription URL
    let subscription: String

    /// Channel type for request
    let channel: BayeuxChannel

    /// Uniqle client id for socket
    var clientId: String?

    /// Model must conform to Hashable
    var hashValue: Int {
        return subscription.hashValue
    }

    public init(subscription: String, channel: BayeuxChannel, clientId: String?) {
        self.subscription = subscription
        self.channel = channel
        self.clientId = clientId
    }
}

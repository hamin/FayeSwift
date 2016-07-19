//
//  FayeClient+Transport.swift
//  Pods
//
//  Created by Shams Ahmed on 19/07/2016.
//
//

import Foundation

// MARK: Transport Delegate
extension FayeClient {
    public func didConnect() {
        self.connectionInitiated = false;
        self.handshake()
    }
    
    public func didDisconnect(error: NSError?) {
        self.delegate?.disconnectedFromServer(self)
        self.connectionInitiated = false
        self.fayeConnected = false
    }
    
    public func didFailConnection(error: NSError?) {
        self.delegate?.connectionFailed(self)
        self.connectionInitiated = false
        self.fayeConnected = false
    }
    
    public func didWriteError(error: NSError?) {
        self.delegate?.fayeClientError(self, error: error ?? NSError(error: .TransportWrite))
    }
    
    public func didReceiveMessage(text: String) {
        self.receive(text)
    }
    
    public func didReceivePong() {
        self.delegate?.pongReceived(self)
    }
}

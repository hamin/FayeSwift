//
//  FayeClient.swift
//  FayeSwift
//
//  Created by Haris Amin on 8/31/14.
//  Copyright (c) 2014 Haris Amin. All rights reserved.
//

import Foundation

// MARK: Custom Extensions
extension String {
    subscript (i: Int) -> String {
        return String(Array(self)[i])
    }
}


// MARK: BayuexChannel Messages
enum BayeuxChannel : Printable {
    case HANDSHAKE_CHANNEL;
    case CONNECT_CHANNEL;
    case DISCONNECT_CHANNEL;
    case SUBSCRIBE_CHANNEL;
    case UNSUBSCRIBE_CHANNEL;
    
    var description : String {
        switch self {
            // Use Internationalization, as appropriate.
        case .HANDSHAKE_CHANNEL: return "/meta/handshake";
        case .CONNECT_CHANNEL: return "/meta/connect";
        case .DISCONNECT_CHANNEL: return "/meta/disconnect";
        case .SUBSCRIBE_CHANNEL: return "/meta/subscribe";
        case .UNSUBSCRIBE_CHANNEL: return "/meta/unsubscribe";
            }
    }
}


// MARK: Type Aliases
typealias ChannelSubscriptionBlock = (NSDictionary) -> Void

// MARK: FayeClientDelegate Protocol
@objc protocol FayeClientDelegate{
    optional func messageReceived(messageDict: NSDictionary, channel: String)
    optional func connectedToServer()
    optional func disconnectedFromServer()
    optional func connectionFailed()
    optional func didSubscribeToChannel(channel:String)
    optional func didUnsubscribeFromChannel(channel:String)
    optional func subscriptionFailedWithError(error:String)
    optional func fayeClientError(error:NSError)
}

protocol Transport{
    func writeString(aString:String)
    func openConnection()
    func closeConnection()
}

public protocol TransportDelegate: class{
    func didConnect()
    func didFailConenction(error:NSError?)
    func didDisconnect()
    func didWriteError(error:NSError?)
    func didReceiveMessage(text:String)
}

public class WebsocketTransport: Transport, WebSocketDelegate {
    var urlString:String?
    var webSocket:WebSocket?
    public weak var delegate:TransportDelegate?
    
    convenience required public init(url: String) {
        self.init()
        self.urlString = url
    }
    
    func openConnection(){
        self.closeConnection()
        self.webSocket = WebSocket(url: NSURL(string:self.urlString!)!)
        self.webSocket!.delegate = self;
        self.webSocket!.connect()
    }
    
    func closeConnection(){
        if(self.webSocket != nil){
            self.webSocket!.delegate = nil
            self.webSocket!.disconnect()
            self.webSocket = nil;
        }
    }
    
    func writeString(aString:String){
        self.webSocket?.writeString(aString)
    }

    // MARK: Websocket Delegate
    public func websocketDidConnect() {
        println("websocket is connected")
        self.delegate?.didConnect()
    }
    
    public func websocketDidDisconnect(error: NSError?) {
        
        if(error == nil){
            println("websocket lost connection!")
            self.delegate?.didDisconnect()
        }else{
            println("websocket is disconnected: \(error!.localizedDescription)")
            self.delegate?.didFailConenction(error)
        }
    }
    
    public func websocketDidWriteError(error: NSError?) {
        if(error == nil){
            println("websocket write failed: ERROR IS NIL!")
        }else{
            println("websocket write failed: \(error!.localizedDescription)")
        }
        self.delegate?.didWriteError(error)
    }
    
    public func websocketDidReceiveMessage(text: String) {
        println("got some text: \(text)")
        self.delegate?.didReceiveMessage(text)
    }
    
    // MARK: TODO
    public func websocketDidReceiveData(data: NSData) {
        println("got some data: \(data.length)")
        //self.socket.writeData(data)
    }
}

// MARK: FayeClient
class FayeClient : TransportDelegate {
    var fayeURLString:String
    var webSocket:WebSocket?
    var fayeClientId:String?
    var delegate:FayeClientDelegate?
    var transportDelegate:TransportDelegate?
    var transport:WebsocketTransport?
    
    private var fayeConnected:Bool?
    private var connectionExtension:NSDictionary?
    private var connectionInitiated:Bool?
    private var messageNumber:UInt32 = 0
    
    private var queuedSubscriptions = NSMutableSet()
    private var pendingSubscriptions = NSMutableSet()
    private var openSubscriptions = NSMutableSet()
    
    private var channelSubscriptionBlocks = Dictionary<String,ChannelSubscriptionBlock>()
    
    init(aFayeURLString:String, channel:String?) {
        self.fayeURLString = aFayeURLString
        self.fayeConnected = false;
        
        self.transport = WebsocketTransport(url: aFayeURLString)
        self.transport!.delegate = self;
        
        if(channel != nil){
            self.queuedSubscriptions.addObject(channel!)
        }
        self.connectionInitiated = false
    }
    
    convenience init(aFayeURLString:String, channel:String, channelBlock:ChannelSubscriptionBlock){
        self.init(aFayeURLString: aFayeURLString, channel: channel)
        self.channelSubscriptionBlocks[channel] = channelBlock;
    }
    
    func connectToServer(){
        if(self.connectionInitiated != true){
            self.transport?.openConnection()
            self.connectionInitiated = true;
        }
    }
    
    func disconnectFromServer(){
        self.disconnect()
    }
    
    func sendMessage(messageDict: NSDictionary, channel:String){
        
        self.publish(messageDict as Dictionary, channel: channel)
    }
    
    func sendMessage(messageDict:[String:AnyObject], channel:String){
        self.publish(messageDict, channel: channel)
    }
    
    func subscribeToChannel(channel:String){
        if(self.isSubscribedToChannel(channel) || self.pendingSubscriptions.containsObject(channel) ){
            return
        }
        
        if(self.fayeConnected == true){
            self.subscribe(channel)
        }else{
            self.queuedSubscriptions.addObject(channel)
        }
    }
    
    func subscribeToChannel(channel:String, block:ChannelSubscriptionBlock){
        self.subscribeToChannel(channel)
        self.channelSubscriptionBlocks[channel] = block;
    }
    
    func unsubscribeFromChannel(channel:String){
        self.queuedSubscriptions.removeObject(channel)
        self.unsubscribe(channel)
        self.channelSubscriptionBlocks[channel] = nil;
    }
    
    func isSubscribedToChannel(channel:String) -> (Bool){
        return self.openSubscriptions.containsObject(channel)
    }
    
    func webSocketConnected() -> (Bool){
        return self.webSocket!.isConnected
    }
}


// MARK: Transport Delegate
private extension FayeClient {
    internal func didConnect() {
        println("Transport websocket is connected")
        self.connectionInitiated = false;
        self.handshake()
    }
    
    internal func didDisconnect() {
        println("Transport websocket lost connection!")
        self.delegate?.disconnectedFromServer?()
        self.connectionInitiated = false
        self.fayeConnected = false
    }
    
    internal func didFailConenction(error: NSError?) {
        println("Transport websocket is disconnected: \(error!.localizedDescription)")
        self.delegate?.connectionFailed?()
        self.connectionInitiated = false
        self.fayeConnected = false
    }
    
    internal func didWriteError(error: NSError?) {
        if(error == nil){
            println("Transport websocket write failed: ERROR IS NIL!")
        }else{
            println("Transport websocket write failed: \(error!.localizedDescription)")
            self.delegate?.fayeClientError?(error!)
        }
    }
    
    internal func didReceiveMessage(text: String) {
        println("Transport got some text: \(text)")
        self.receive(text)
    }
    
}

// MARK: Private Bayuex Methods
private extension FayeClient {
    func parseFayeMessage(messageJSON:JSON){
        
        let messageDict = messageJSON[0]
        let channel = messageDict["channel"].stringValue as String!
        
        switch(channel)
            {
        case BayeuxChannel.HANDSHAKE_CHANNEL.description:
            println("HANDSHAKE_CHANNEL")
            self.fayeClientId = messageDict["clientId"].stringValue
            if(messageDict["successful"].numberValue == 1){
                
                self.delegate?.connectedToServer?()
                self.fayeConnected = true;
                self.connect()
                self.subscribeQueuedSubscriptions()
                
            }else{
                // OOPS
            }
            
        case BayeuxChannel.CONNECT_CHANNEL.description:
            println("CONNECT_CHANNEL")
            if(messageDict["successful"].numberValue == 1){
                self.fayeConnected = true;
                self.connect()
            }else{
                // OOPS
            }
        case BayeuxChannel.DISCONNECT_CHANNEL.description:
            println("DISCONNECT_CHANNEL")
            if(messageDict["successful"].numberValue == 1){
                self.fayeConnected = false;
                self.transport?.closeConnection()
                self.delegate?.disconnectedFromServer?()
            }else{
                // OOPS
            }
        case BayeuxChannel.SUBSCRIBE_CHANNEL.description:
            println("SUBSCRIBE_CHANNEL")
            
            let subscription = messageJSON[0]["subscription"].stringValue as String!
            self.pendingSubscriptions.removeObject(subscription)
            let success = messageJSON[0]["successful"].numberValue as Int!
            
            if( success == 1){
                self.openSubscriptions.addObject(subscription)
                self.delegate?.didSubscribeToChannel?(subscription)
            }else{
                // Subscribe Failed
                let error = messageJSON[0]["error"].stringValue as String!
                self.delegate?.subscriptionFailedWithError?(error)
            }
        case BayeuxChannel.UNSUBSCRIBE_CHANNEL.description:
            println("UNSUBSCRIBE_CHANNEL")
            
            let subscription = messageJSON[0]["subscription"].stringValue as String!
            self.openSubscriptions.removeObject(subscription)
            self.delegate?.didUnsubscribeFromChannel?(subscription)
        default:
            let chan = messageJSON[0]["channel"].stringValue!
            
            if(self.isSubscribedToChannel(chan)){
                println("New Message on \(channel)")
                let data: AnyObject! = messageJSON[0]["data"].object
                
                if(data != nil){
                    // Call channel subscription block if there is one
                    if let channelBlock = self.channelSubscriptionBlocks[channel]{
                        channelBlock(data as NSDictionary)
                    }else{
                        self.delegate?.messageReceived?(data as NSDictionary, channel: chan)
                    }
                    
                }else{
                    println("For some reason data is nil, maybe double posting?!")
                }
                
            }else{
                println("weird channel")
            }
            
        }
        
    }
    
    /**
    Bayeux messages
    */
    
    // Bayeux Handshake
    // "channel": "/meta/handshake",
    // "version": "1.0",
    // "minimumVersion": "1.0beta",
    // "supportedConnectionTypes": ["long-polling", "callback-polling", "iframe", "websocket]
    func handshake() {
        var connTypes:NSArray = ["long-polling", "callback-polling", "iframe", "websocket"]
        var dict = [String: AnyObject]()
        dict["channel"] = BayeuxChannel.HANDSHAKE_CHANNEL.description
        dict["version"] = "1.0"
        dict["minimumVersion"] = "1.0beta"
        dict["supportedConnectionTypes"] = connTypes
        
        let string = JSONStringify(dict)
        self.transport?.writeString(string)
    }
    
    // Bayeux Connect
    // "channel": "/meta/connect",
    // "clientId": "Un1q31d3nt1f13r",
    // "connectionType": "long-polling"
    func connect(){
        var dict:[String:AnyObject] = ["channel": BayeuxChannel.CONNECT_CHANNEL.description, "clientId": self.fayeClientId!, "connectionType": "websocket"]
        
        let string = JSONStringify(dict)
        self.transport?.writeString(string)
    }
    
    // Bayeux Disconnect
    // "channel": "/meta/disconnect",
    // "clientId": "Un1q31d3nt1f13r"
    func disconnect(){
        var dict:[String:AnyObject] = ["channel": BayeuxChannel.DISCONNECT_CHANNEL.description, "clientId": self.fayeClientId!, "connectionType": "websocket"]
        let string = JSONStringify(dict)
        self.transport?.writeString(string)
    }
    
    // Bayeux Subscribe
    // {
    // "channel": "/meta/subscribe",
    // "clientId": "Un1q31d3nt1f13r",
    // "subscription": "/foo/**"
    // }
    func subscribe(channel:String){
        var dict:[String:AnyObject] = ["channel": BayeuxChannel.SUBSCRIBE_CHANNEL.description, "clientId": self.fayeClientId!, "subscription": channel]
        let string = JSONStringify(dict)
        self.transport?.writeString(string)
        self.pendingSubscriptions.addObject(channel)
    }
    
    // Bayeux Unsubscribe
    // {
    // "channel": "/meta/unsubscribe",
    // "clientId": "Un1q31d3nt1f13r",
    // "subscription": "/foo/**"
    // }
    func unsubscribe(channel:String){
        var dict:[String:AnyObject] = ["channel": BayeuxChannel.UNSUBSCRIBE_CHANNEL.description, "clientId": self.fayeClientId!, "subscription": channel]
        let string = JSONStringify(dict)
        self.transport?.writeString(string)
    }
    
    // Bayeux Publish
    // {
    // "channel": "/some/channel",
    // "clientId": "Un1q31d3nt1f13r",
    // "data": "some application string or JSON encoded object",
    // "id": "some unique message id"
    // }
    func publish(data:[String:AnyObject], channel:String){
        if(self.fayeConnected != nil){
            var dict:[String:AnyObject] = ["channel": channel, "clientId": self.fayeClientId!, "id": self.nextMessageId(), "data": data]
            
            var string = JSONStringify(dict)
            println("THIS IS THE PUBSLISH STRING: \(string)")
            self.transport?.writeString(string)
        }else{
            // Faye is not connected
        }
    }
}

// MARK: Private Internal methods
private extension FayeClient {
    func subscribeQueuedSubscriptions(){
        // if there are any outstanding open subscriptions resubscribe
        if(self.queuedSubscriptions.count > 0){
            let queue:NSSet = self.queuedSubscriptions.copy() as NSSet
            
            for channel in queue{
                self.queuedSubscriptions.removeObject(channel)
                self.subscribe(channel as String)
            }
        }
    }
    
    func send(message: NSDictionary){
        // Parse JSON
        var writeError:NSError?
        var jsonData:NSData = NSJSONSerialization.dataWithJSONObject(message, options:nil, error: &writeError)!
        
        if(writeError == nil){
            println("COuldn't parse json")
        }else{
            var jsonString:NSString = NSString(data: jsonData, encoding:NSUTF8StringEncoding)!
            self.transport?.writeString(jsonString)
        }
    }
    
    func receive(message: String){
        // Parse JSON
        var jsonData = message.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
        var json = JSON(data: jsonData!)
        self.parseFayeMessage(json)
    }
    
    // http://iosdevelopertips.com/swift-code/base64-encode-decode-swift.html
    func nextMessageId() -> String{
        self.messageNumber++
        if(self.messageNumber >= UINT32_MAX){
            messageNumber = 0
        }
        var str = "\(self.messageNumber)"
        println("Original: \(str)")
        
        // UTF 8 str from original
        // NSData! type returned (optional)
        let utf8str = str.dataUsingEncoding(NSUTF8StringEncoding)
        
        // Base64 encode UTF 8 string
        // fromRaw(0) is equivalent to objc 'base64EncodedStringWithOptions:0'
        // Notice the unwrapping given the NSData! optional
        // NSString! returned (optional)
        let base64Encoded = utf8str?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions())
        println("Encoded:  \(base64Encoded)")
        
        // Base64 Decode (go back the other way)
        // Notice the unwrapping given the NSString! optional
        // NSData returned
        let data = NSData(base64EncodedString: base64Encoded!, options: NSDataBase64DecodingOptions())
        
        // Convert back to a string
        let base64Decoded = NSString(data: data!, encoding: NSUTF8StringEncoding)
        println("Decoded:  \(base64Decoded)")
        
        return base64Decoded!
    }
    
    // JSON Helpers
    func JSONStringify(jsonObj: AnyObject) -> String {
        var e: NSError?
        let jsonData: NSData! = NSJSONSerialization.dataWithJSONObject(
            jsonObj,
            options: NSJSONWritingOptions(0),
            error: &e)
        if e != nil {
            return ""
        } else {
            return NSString(data: jsonData, encoding: NSUTF8StringEncoding)!
        }
    }
}
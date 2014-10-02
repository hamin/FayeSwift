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

// MARK: FayeClient
class FayeClient : WebsocketDelegate {
    var fayeURLString:String
    var webSocket:Websocket?
    var fayeClientId:String?
    var delegate:FayeClientDelegate?
    
    private var fayeConnected:Bool?
    private var connectionExtension:NSDictionary?
    private var connectionInitiated:Bool?
    private var messageNumber:UInt32 = 0
    
    private var queuedSubscriptions = NSMutableSet()
    private var pendingSubscriptions = NSMutableSet()
    private var openSubscriptions = NSMutableSet()
    
    init(aFayeURLString:String, channel:String?) {
        self.fayeURLString = aFayeURLString
        self.fayeConnected = false;
        
        if(channel != nil){
            self.queuedSubscriptions.addObject(channel!)
        }
        self.connectionInitiated = false
    }
    
    func connectToServer(){
        if(self.connectionInitiated != true){
            self.openWebSocketConnection()
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
    
    func unsubscribeFromChannel(channel:String){
        self.queuedSubscriptions.removeObject(channel)
        self.unsubscribe(channel)
    }
    
    func isSubscribedToChannel(channel:String) -> (Bool){
        return self.openSubscriptions.containsObject(channel)
    }
    
    func webSocketConnected() -> (Bool){
        return self.webSocket!.isConnected
    }
}

// MARK: Websocket Delegate
private extension FayeClient {
    internal func websocketDidConnect() {
        println("websocket is connected")
        self.connectionInitiated = false;
        self.handshake()
    }
    
    internal func websocketDidDisconnect(error: NSError?) {
        
        if(error == nil){
            println("websocket lost connection!")
            self.delegate?.disconnectedFromServer?()
        }else{
            println("websocket is disconnected: \(error!.localizedDescription)")
            self.delegate?.connectionFailed?()
        }
        self.connectionInitiated = false
        self.fayeConnected = false
    }
    
    internal func websocketDidWriteError(error: NSError?) {
        if(error == nil){
            println("websocket write failed: ERROR IS NIL!")
        }else{
            println("websocket write failed: \(error!.localizedDescription)")
            self.delegate?.fayeClientError?(error!)
        }
    }
    
    internal func websocketDidReceiveMessage(text: String) {
        println("got some text: \(text)")
        self.receive(text)
    }
    
    // MARK: TODO
    internal func websocketDidReceiveData(data: NSData) {
        println("got some data: \(data.length)")
        //self.socket.writeData(data)
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
                self.closeWebSocketConnection()
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
                println("New Message on `channel`")
                let data: AnyObject! = messageJSON[0]["data"].object
                
                if(data != nil){
                    self.delegate?.messageReceived?(data as NSDictionary, channel: chan)
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
        self.webSocket!.writeString(string)
    }
    
    // Bayeux Connect
    // "channel": "/meta/connect",
    // "clientId": "Un1q31d3nt1f13r",
    // "connectionType": "long-polling"
    func connect(){
        var dict:[String:AnyObject] = ["channel": BayeuxChannel.CONNECT_CHANNEL.description, "clientId": self.fayeClientId!, "connectionType": "websocket"]
        
        let string = JSONStringify(dict)
        self.webSocket!.writeString(string)
    }
    
    // Bayeux Disconnect
    // "channel": "/meta/disconnect",
    // "clientId": "Un1q31d3nt1f13r"
    func disconnect(){
        var dict:[String:AnyObject] = ["channel": BayeuxChannel.DISCONNECT_CHANNEL.description, "clientId": self.fayeClientId!, "connectionType": "websocket"]
        let string = JSONStringify(dict)
        self.webSocket!.writeString(string)
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
        self.webSocket!.writeString(string)
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
        self.webSocket!.writeString(string)
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
            self.webSocket!.writeString(string)
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
            NSLog("COuldn't parse json")
        }else{
            var jsonString:NSString = NSString(data: jsonData, encoding:NSUTF8StringEncoding)
            self.webSocket?.writeString(jsonString)
        }
        
        
    }
    
    func receive(message: String){
        // Parse JSON
        var jsonData = message.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
        var json = JSON(data: jsonData!)
        self.parseFayeMessage(json)
    }
    
    /**
    Websocket Connection helpers
    */
    func openWebSocketConnection(){
        self.closeWebSocketConnection()
        
        self.webSocket = Websocket(url: NSURL.URLWithString(self.fayeURLString))
        self.webSocket!.delegate = self;
        self.webSocket!.connect()
        self.connectionInitiated = true
    }
    
    func closeWebSocketConnection(){
        if(self.webSocket != nil){
            self.webSocket!.delegate = nil
            self.webSocket!.disconnect()
            self.webSocket = nil;
        }
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
        let base64Encoded = utf8str?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.fromRaw(0)!)
        println("Encoded:  \(base64Encoded)")
        
        // Base64 Decode (go back the other way)
        // Notice the unwrapping given the NSString! optional
        // NSData returned
        let data = NSData(base64EncodedString: base64Encoded!, options: NSDataBase64DecodingOptions.fromRaw(0)!)
        
        // Convert back to a string
        let base64Decoded = NSString(data: data, encoding: NSUTF8StringEncoding)
        println("Decoded:  \(base64Decoded)")
        
        return base64Decoded
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
            return NSString(data: jsonData, encoding: NSUTF8StringEncoding)
        }
    }
}
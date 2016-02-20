//
//  ViewController.swift
//  FayeSwift
//
//  Created by Haris Amin on 01/25/2016.
//  Copyright (c) 2016 Haris Amin. All rights reserved.
//

import UIKit
import FayeSwift

class ViewController: UIViewController, UITextFieldDelegate, FayeClientDelegate {

  @IBOutlet weak var textField: UITextField!
  @IBOutlet weak var textView: UITextView!
  
  /// Example FayeClient
  let client:FayeClient = FayeClient(aFayeURLString: "ws://localhost:5222/faye", channel: "/cool")
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    client.delegate = self;
    client.connectToServer()
    
    let channelBlock:ChannelSubscriptionBlock = {(messageDict) -> Void in
      let text: AnyObject? = messageDict["text"]
      print("Here is the Block message: \(text)")
    }
    client.subscribeToChannel("/awesome", block: channelBlock)
    
    
    
    let delayTime = dispatch_time(DISPATCH_TIME_NOW,
      Int64(3 * Double(NSEC_PER_SEC)))
    dispatch_after(delayTime, dispatch_get_main_queue()) {
      self.client.unsubscribeFromChannel("/awesome")
    }
    
    dispatch_after(delayTime, dispatch_get_main_queue()) { 
      self.client.subscribeToChannel("/awesome", block: channelBlock)
    }
  }
    
  // MARK:
  // MARK: TextfieldDelegate

  func textFieldShouldReturn(textField: UITextField) -> Bool {
    // client.sendMessage(["text": textField.text], channel: "/cool")
    client.sendMessage(["text" : textField.text as! AnyObject], channel: "/cool")
    return false;
  }
    
  // MARK:
  // MARK: TextfieldDelegate
  
  func connectedtoser(client: FayeClient) {
    print("Connected to Faye server")
  }
  
  func connectionFailed(client: FayeClient) {
    print("Failed to connect to Faye server!")
  }
  
  func disconnectedFromServer(client: FayeClient) {
    print("Disconnected from Faye server")
  }
  
  func didSubscribeToChannel(client: FayeClient, channel: String) {
    print("Subscribed to channel \(channel)")
  }
  
  func didUnsubscribeFromChannel(client: FayeClient, channel: String) {
    print("Unsubscribed from channel \(channel)")
  }
  
  func subscriptionFailedWithError(client: FayeClient, error: String) {
    print("Subscription failed")
  }
  
  func messageReceived(client: FayeClient, messageDict: NSDictionary, channel: String) {
    let text: AnyObject? = messageDict["text"]
    print("Here is the message: \(text)")
//        self.client.subscribeToChannel("/newchannelbaby")
//        self.client.unsubscribeFromChannel(channel)
  }
}


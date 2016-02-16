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
  
    // ws://localhost:5222/faye
  let client: FayeClient = FayeClient(aFayeURLString: "wss://fusion.fusion-universal.com:8080/faye", channel: "/cool")
  
  // MARK:
  // MARK: Lifecycle
    
  override func viewDidLoad() {
    super.viewDidLoad()
    
    client.delegate = self;
    client.connectToServer()
    
    let channelBlock:ChannelSubscriptionBlock = {(messageDict) -> Void in
      let text: AnyObject? = messageDict["text"]
      print("Here is the Block message: \(text)")
    }
    
    client.subscribeToChannel("/awesome", block: channelBlock)
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(3 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
      self.client.unsubscribeFromChannel("/awesome")
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
      print("resubscribe to awesome")
      self.client.subscribeToChannel("/awesome", block: channelBlock)
    }
  }
  
  // MARK:
  // MARK: TextfieldDelegate

  func textFieldShouldReturn(textField: UITextField) -> Bool {
    client.sendMessage(["text" : textField.text as! AnyObject], channel: "/cool")

    return false;
  }
  
  // MARK:
  // MARK: FayeClientDelegate

  func connectedToServer() {
    print("Connected to Faye server")
  }
  
  func connectionFailed(error: NSError?) {
    print("Failed to connect to Faye server with \(error)")
  }
  
  func disconnectedFromServer(error: NSError) {
    print("Disconnected from Faye server")
  }
  
  func didSubscribeToChannel(channel: String) {
    print("Subscribed to channel \(channel)")
  }
  
  func didUnsubscribeFromChannel(channel: String) {
    print("Unsubscribed from channel \(channel)")
  }
  
  func subscriptionFailedWithError(error: String) {
    print("Subscription failed with \(error)")
  }
  
  func messageReceived(messageDict: NSDictionary, channel: String) {
    let text: AnyObject? = messageDict["text"]
    print("Here is the message: \(text)")
//        self.client.subscribeToChannel("/newchannelbaby")
//        self.client.unsubscribeFromChannel(channel)
  }
}

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
  
  let client: FayeClient = FayeClient(aFayeURLString: "ws://localhost:5222/faye", channel: "/cool")
  
  // MARK:
  // MARK: Lifecycle
    
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
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
      print("unsub")
      self.client.unsubscribeFromChannel("/awesome")
    }
    
    _ = dispatch_time(DISPATCH_TIME_NOW,
      Int64(5 * Double(NSEC_PER_SEC)))
    dispatch_after(delayTime, dispatch_get_main_queue()) {
      print("resub")
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
  // MARK: FayeClientDelegate

  func connectedToServer() {
    print("Connected to Faye server")
  }
  
  func connectionFailed() {
    print("Failed to connect to Faye server!")
  }
  
  func disconnectedFromServer() {
    print("Disconnected from Faye server")
  }
  
  func didSubscribeToChannel(channel: String) {
    print("subscribed to channel \(channel)")
  }
  
  func didUnsubscribeFromChannel(channel: String) {
    print("UNsubscribed from channel \(channel)")
  }
  
  func subscriptionFailedWithError(error: String) {
    print("SUBSCRIPTION FAILED!!!!")
  }
  
  func messageReceived(messageDict: NSDictionary, channel: String) {
    let text: AnyObject? = messageDict["text"]
    print("Here is the message: \(text)")
//        self.client.subscribeToChannel("/newchannelbaby")
//        self.client.unsubscribeFromChannel(channel)
  }
}

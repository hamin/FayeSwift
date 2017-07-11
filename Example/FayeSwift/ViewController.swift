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
  
  // MARK:
  // MARK: Lifecycle
    
  override func viewDidLoad() {
    super.viewDidLoad()
    
    client.delegate = self;
    client.transportHeaders = ["X-Custom-Header": "Custom Value"]
    client.connectToServer()
    
    let channelBlock:ChannelSubscriptionBlock = {(messageDict) -> Void in
      if let text = messageDict["text"] {
        print("Here is the Block message: \(text)")
      }
    }
    _ = client.subscribeToChannel("/awesome", block: channelBlock)
    
    let delayTime = DispatchTime.now() + Double(Int64(5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
    DispatchQueue.main.asyncAfter(deadline: delayTime) {
      self.client.unsubscribeFromChannel("/awesome")
    }
    
    DispatchQueue.main.asyncAfter(deadline: delayTime) {
      let model = FayeSubscriptionModel(subscription: "/awesome", clientId: nil)
        
      _ = self.client.subscribeToChannel(model, block: { [unowned self] messages in
        print("awesome response: \(messages)")
        
        self.client.sendPing("Ping".data(using: String.Encoding.utf8)!, completion: {
          print("got pong")
        })
      })
    }
  }
    
  // MARK:
  // MARK: TextfieldDelegate

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    client.sendMessage(["text" : textField.text!], channel: "/cool")
    return false;
  }
    
  // MARK:
  // MARK: FayeClientDelegate
  
  func connectedtoser(_ client: FayeClient) {
    print("Connected to Faye server")
  }
  
  func connectionFailed(_ client: FayeClient) {
    print("Failed to connect to Faye server!")
  }
  
  func disconnectedFromServer(_ client: FayeClient) {
    print("Disconnected from Faye server")
  }
  
  func didSubscribeToChannel(_ client: FayeClient, channel: String) {
    print("Subscribed to channel \(channel)")
  }
  
  func didUnsubscribeFromChannel(_ client: FayeClient, channel: String) {
    print("Unsubscribed from channel \(channel)")
  }
  
  func subscriptionFailedWithError(_ client: FayeClient, error: subscriptionError) {
    print("Subscription failed")
  }
  
  func messageReceived(_ client: FayeClient, messageDict: NSDictionary, channel: String) {
    if let text = messageDict["text"] {
      print("Here is the message: \(text)")
    }
  }
  
  func pongReceived(_ client: FayeClient) {
    print("pong")
  }
}

//
//  ViewController.swift
//  FayeSwiftDemo
//
//  Created by Haris Amin on 10/1/14.
//  Copyright (c) 2014 Haris Amin. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITextFieldDelegate, FayeClientDelegate {
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var textView: UITextView!
    
    var client:FayeClient?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        client = FayeClient(aFayeURLString: "ws://localhost:5222/faye", channel: "/cool")
        client!.delegate = self;
        
        client!.connectToServer()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        client!.sendMessage(["text": textField.text], channel: "/cool")
        return false;
    }
    
    
    func connectedToServer() {
        println("Connected to faye server")
    }
    
    func connectionFailed() {
        println("VIEW CONTROLLER CONNECTION FAILED!")
    }
    
    func disconnectedFromServer() {
        println("Disconnected from faye server")
    }
    
    func didSubscribeToChannel(channel: String) {
        println("subscribed to channel \(channel)")
    }
    
    func didUnsubscribeFromChannel(channel: String) {
        println("UNsubscribed from channel \(channel)")
    }
    
    func subscriptionFailedWithError(error: String) {
        println("SUBSCRIPTION FAILED!!!!")
    }
    
    func messageReceived(messageDict: NSDictionary, channel: String) {
        let text: AnyObject? = messageDict["text"]
        println("Here is the message: \(text)")
        
        self.client?.unsubscribeFromChannel(channel)
    }


}


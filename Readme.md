
A simple Swift client library for the [Faye](http://faye.jcoglan.com/) publish-subscribe messaging server. FayeObjC is implemented atop the [Starscream](https://github.com/daltoniam/starscream) Swift web socket library and will work on both Mac (pending Xcode 6 Swift update) and iPhone projects.

It was heavily inspired by the Objective-C client found here: [FayeObjc](https://github.com/pcrawfor/FayeObjC)

## Example

### Installation

For now, add the following files to your project: `FayeClient.swift`, `Websocket.swift`, and `SwiftyJSON.swift`.

### Initializing Client

You can open a connection to your faye server. Note that `client` is probably best as a property, so your delegate can stick around. You can initiate a client with a subscription to a specific channel.

```swift
client = FayeClient(aFayeURLString: "ws://localhost:5222/faye", channel: "/cool")
client!.delegate = self
client!.connectToServer()
```

After you are connected, we some delegate methods we need to implement.

### connectedToServer

websocketDidConnect is called as soon as the client connects to the server.

```swift
func connectedToServer() {
   println("Connected to Faye server")
}
```

### connectionFailed

websocketDidDisconnect is called as soon as the client is disconnected from the server.

```swift
func connectionFailed() {
   println("Failed to connect to Faye server!")
}
```

### disconnectedFromServer

websocketDidWriteError is called when the client gets an error on websocket connection.

```swift
func disconnectedFromServer() {
   println("Disconnected from Faye server")
}
```

### didSubscribeToChannel

websocketDidReceiveMessage is called when the client gets a text frame from the connection.

```swift
func didSubscribeToChannel(channel: String) {
   println("subscribed to channel \(channel)")
}
```

### didUnsubscribeFromChannel

websocketDidReceiveData is called when the client gets a binary frame from the connection.

```swift
func didUnsubscribeFromChannel(channel: String) {
   println("UNsubscribed from channel \(channel)")
}
```

The delegate methods give you a simple way to handle data from the server, but how do you send data?

### subscriptionFailedWithError

The writeData method gives you a simple way to send `NSData` (binary) data to the server.

```swift
func subscriptionFailedWithError(error: String) {
   println("SUBSCRIPTION FAILED!!!!")
}
```

### messageReceived

The writeString method is the same as writeData, but sends text/string.

```swift
func messageReceived(messageDict: NSDictionary, channel: String) {
   let text: AnyObject? = messageDict["text"]
   println("Here is the message: \(text)")
   
   self.client?.unsubscribeFromChannel(channel)
}
```

## Example Server

There is a sample faye server using the NodeJS Faye library. If you have NodeJS installed just run the following commands to install the package:

```javascript
npm install
```

And then you can start the Faye server like so:

```javascript
node faye_server.js
```
## Example Project

Check out the FayeSwiftDemo project to see how to setup a simple connection to a Faye server.

## Requirements

FayeSwift requires at least iOS 7/OSX 10.10 or above.

## Installation

Add the `starscream.xcodeproj` to your Xcode project. Once that is complete, in your "Build Phases" add the `starscream.framework` to your "Link Binary with Libraries" phase.

## TODOs

- [ ] Cocoapods Integration
- [ ] Complete Docs
- [ ] Add Unit Tests
- [ ] Rethink use of optionals (?)
- [ ] Add block handlers (?)
- [ ] Support for a long-polling transport (?)

## License

FayeSwift is licensed under the MIT License.

## Libraries

* [Starscream](https://github.com/daltoniam)
* [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON)
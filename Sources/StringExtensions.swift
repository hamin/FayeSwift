//
//  StringExtensions.swift
//  Pods
//
//  Created by Haris Amin on 2/20/16.
//
//

// MARK: Custom Extensions
extension String {
  subscript (i: Int) -> String {
    return String(Array(self.characters)[i])
  }
  
  // http://iosdevelopertips.com/swift-code/base64-encode-decode-swift.html
  func encodedString() -> String {
    // UTF 8 str from original
    // NSData! type returned (optional)
    guard let utf8str = self.data(using: String.Encoding.utf8) else {
        return ""
    }
    
    // Base64 encode UTF 8 string
    // fromRaw(0) is equivalent to objc 'base64EncodedStringWithOptions:0'
    // Notice the unwrapping given the NSData! optional
    // NSString! returned (optional)
    let base64Encoded = utf8str.base64EncodedString(options: NSData.Base64EncodingOptions())
    
    // Base64 Decode (go back the other way)
    // Notice the unwrapping given the NSString! optional
    // NSData returned
    guard let data = Data(
        base64Encoded: base64Encoded,
        options: NSData.Base64DecodingOptions()),
    let base64Decoded = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else {
            return ""
    }
    
    return base64Decoded as String
  }
}

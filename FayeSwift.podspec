Pod::Spec.new do |s|
  s.name             = "FayeSwift"
  s.version          = "0.4.0"
  s.summary          = "A pure Swift Faye (Bayeux) Client"
  s.description      = <<-DESC
                        A Pure Swift Client Library for the Faye (Bayeux/Comet) Pub-Sub messaging server.
                        This client has been tested with the Faye (http://faye.jcoglan.com) implementation of the
                        Bayeux protocol. Currently only supports Websocket transport.
                       DESC
  s.homepage         = "https://github.com/hamin/FayeSwift"
  s.license          = "MIT"
  s.author           = { "Haris Amin" => "aminharis7@gmail.com" }
  s.source           = { :git => "https://github.com/hamin/FayeSwift.git", :tag => s.version.to_s }
  s.social_media_url = "https://twitter.com/harisamin"
  s.requires_arc = true
  s.osx.deployment_target = "10.10"
  s.ios.deployment_target = "8.0"
  s.tvos.deployment_target = "9.0"
  s.source_files = "Sources/*.swift"
  s.dependency "Starscream", '~> 4.0.0'
  s.dependency "SwiftyJSON", '~> 5.0.0'
end

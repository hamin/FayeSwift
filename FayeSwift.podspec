#
# Be sure to run `pod lib lint FayeSwift.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "FayeSwift"
  s.version          = "0.1.0"
  s.summary          = "A short description of FayeSwift."

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      = <<-DESC
                       DESC

  s.homepage         = "https://github.com/hamin/FayeSwift"
  s.license          = 'MIT'
  s.author           = { "Haris Amin" => "aminharis7@gmail.com" }
  s.source           = { :git => "https://github.com/hamin/FayeSwift.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/harisamin'

  s.requires_arc = true
  s.osx.deployment_target = "10.9"
  s.ios.deployment_target = "8.0"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"

  #s.source_files = 'Pod/Classes/**/*'
  s.source_files = "Sources/*.swift"

  s.dependency 'Starscream', '~> 1.1'
  s.dependency 'SwiftyJSON', '~> 2.3'
end

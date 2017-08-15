Pod::Spec.new do |s|
  s.name         = "MailgunSwift"
  s.version      = "1.0.0"
  s.summary      = "The Mailgun SDK allows your Mac OS X or iOS application to connect with the programmable email platform."
  s.homepage     = "https://github.com/bre7/mailgun-swift"
  s.license      = 'MIT'
  s.author       = { "Jay Baird" => "jay.baird@rackspace.com" }
  s.source       = { :git => 'https://github.com/bre7/mailgun-swift.git', :tag => s.version }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'

  s.source_files = 'Source/*.swift'

  s.dependency 'Alamofire', '~> 4.0'
end

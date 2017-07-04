Pod::Spec.new do |s|
  s.name             = 'SyncServer'
  s.version          = '0.0.5'
  s.summary          = 'iOS Client for the SyncServerII server'

  s.description      = <<-DESC
	SyncServerII enables apps to save user files in users cloud storage, and
	enables safe sharing of those files.
                       DESC

  s.homepage         = 'https://github.com/crspybits/SyncServer-iOSClient'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Christopher Prince' => 'chris@SpasticMuffin.biz' }
  s.source           = { :git => 'https://github.com/crspybits/SyncServer-iOSClient.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'

  s.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS[config=Debug]' => '-DDEBUG',
  }

  s.source_files = 'Client/Classes/**/*.{swift}'
  s.resources = 'Client/Assets/**/*'
  s.preserve_paths = 'Client/Assets/**/*'
    
  s.dependency 'AFNetworking'
  s.dependency 'SMCoreLib'
  s.dependency 'Gloss'
  s.dependency 'SyncServer-Shared'
end

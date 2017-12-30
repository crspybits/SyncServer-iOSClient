# Making use of subspecs to allow user of pod to select sign-in types. See also http://www.dbotha.com/2014/12/04/optional-cocoapod-dependencies/

Pod::Spec.new do |s|
  s.name             = 'SyncServer'
  s.version          = '8.0.0'
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
    'OTHER_SWIFT_FLAGS[config=Debug]' => '$(inherited) -DDEBUG'
  }

  s.source_files = 'Client/Classes/**/*.{swift}'
  
  s.resources = ['Client/Assets/**/*', 'Client/Classes/**/*.{xib}']

  s.preserve_paths = 'Client/Assets/**/*'

  s.dependency 'SMCoreLib', '~> 1.2'
  
  s.dependency 'Gloss', '~> 1.2'
  
  s.dependency 'SyncServer-Shared', '~> 3.3'
  
  s.default_subspec = 'Lite'
  
  s.subspec 'Lite' do |lite|
    # subspec for users who don't want the sign-in's they don't use.
  end
  
  s.subspec 'Facebook' do |facebook|
    facebook.xcconfig =   
        { 'OTHER_SWIFT_FLAGS' => '$(inherited) -DSYNCSERVER_FACEBOOK_SIGNIN' }
    facebook.dependency 'FacebookLogin', '~> 0.2'
    facebook.dependency 'FacebookCore', '~> 0.2'
  end

  s.subspec 'Dropbox' do |dropbox|
    dropbox.xcconfig =   
        { 'OTHER_SWIFT_FLAGS' => '$(inherited) -DSYNCSERVER_DROPBOX_SIGNIN' }
    dropbox.dependency 'SwiftyDropbox', '~> 4.3'
  end
end

# Making use of subspecs to allow user of pod to select sign-in types. See also http://www.dbotha.com/2014/12/04/optional-cocoapod-dependencies/

Pod::Spec.new do |s|
  s.name             = 'SyncServer'
  s.version          = '18.11.0'
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

  s.dependency 'SMCoreLib', '~> 1.4'
  s.dependency 'SyncServer-Shared', '~> 9.8'
  s.dependency 'FileMD5Hash', '~> 2.0'
  s.dependency 'PersistentValue', '~> 0.3'

  s.default_subspec = 'Lite'

  s.swift_version = '3.2'
  
  s.subspec 'Lite' do |lite|
    # subspec for users who don't want the sign-in's they don't use.
  end
  
  s.subspec 'Facebook' do |facebook|
    facebook.xcconfig =   
        { 'OTHER_SWIFT_FLAGS' => '$(inherited) -DSYNCSERVER_FACEBOOK_SIGNIN' }

    # In their repos, these are marked as "beta" -- so I'm fixing on a specific version that is working for me right now.
    facebook.dependency 'FacebookCore', '0.5.0'
    facebook.dependency 'FacebookLogin', '0.5.0'

# 12/11/18; These two are a hack/workaround for a FB issue. See https://stackoverflow.com/questions/35248412/ios-facebook-login-error-unknown-error-building-url-com-facebook-sdk-core-e
    facebook.dependency 'FBSDKCoreKit', '4.38.1'
    facebook.dependency 'FBSDKLoginKit', '4.38.1'
  end

  s.subspec 'Dropbox' do |dropbox|
    dropbox.xcconfig =   
        { 'OTHER_SWIFT_FLAGS' => '$(inherited) -DSYNCSERVER_DROPBOX_SIGNIN' }
    dropbox.dependency 'SwiftyDropbox', '~> 4.8'
  end

  s.subspec 'Google' do |google|
    google.xcconfig =   
        { 'OTHER_SWIFT_FLAGS' => '$(inherited) -DSYNCSERVER_GOOGLE_SIGNIN' }

    # This is a dependency on the https://github.com/crspybits/SMGoogleSignIn *dynamic* framework.
    # In your Podfile, at the very top of the file, put:
    #   source 'https://github.com/crspybits/Specs.git'
    google.dependency 'SMGoogleSignIn', '~> 1.1'
  end
end

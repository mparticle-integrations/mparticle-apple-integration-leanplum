Pod::Spec.new do |s|
    s.name             = "mParticle-Leanplum"
    s.version          = "8.0.2"
    s.summary          = "Leanplum integration for mParticle"

    s.description      = <<-DESC
                       This is the Leanplum integration for mParticle.
                       DESC

    s.homepage         = "https://www.mparticle.com"
    s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
    s.author           = { "mParticle" => "support@mparticle.com" }
    s.source           = { :git => "https://github.com/mparticle-integrations/mparticle-apple-integration-leanplum.git", :tag => s.version.to_s }
    s.social_media_url = "https://twitter.com/mparticle"

    s.ios.deployment_target = "9.0"
    s.ios.source_files      = 'mParticle-Leanplum/*.{h,m,mm}'
    s.ios.dependency 'mParticle-Apple-SDK/mParticle', '~> 8.0'
    s.ios.dependency 'Leanplum-iOS-SDK', '~> 3.1'
    s.ios.frameworks = 'CFNetwork', 'SystemConfiguration', 'Security', 'CoreLocation', 'StoreKit'
    s.ios.weak_frameworks = 'AdSupport'
    s.ios.pod_target_xcconfig = {
        'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/Leanplum-iOS-SDK/**',
        'OTHER_LDFLAGS' => '$(inherited) -framework "Leanplum"',
        'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
    }
    s.ios.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }

end

Pod::Spec.new do |s|
    s.name             = "mParticle-Leanplum"
    s.version          = "6.7.0"
    s.summary          = "Leanplum integration for mParticle"

    s.description      = <<-DESC
                       This is the Leanplum integration for mParticle.
                       DESC

    s.homepage         = "https://www.mparticle.com"
    s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
    s.author           = { "mParticle" => "support@mparticle.com" }
    s.source           = { :git => "https://github.com/mparticle-integrations/mparticle-apple-integration-leanplum.git", :tag => s.version.to_s }
    s.social_media_url = "https://twitter.com/mparticles"
    s.default_subspec  = "DefaultVersion"

    def s.subspec_common(ss)
        ss.ios.deployment_target = "7.0"
        ss.ios.source_files      = 'mParticle-Leanplum/*.{h,m,mm}'
        ss.ios.dependency 'mParticle-Apple-SDK/mParticle', '~> 6.7'
        ss.ios.frameworks = 'CFNetwork', 'SystemConfiguration', 'Security', 'CoreLocation', 'StoreKit'
        ss.ios.weak_frameworks = 'AdSupport'
        ss.ios.pod_target_xcconfig = {
            'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/Leanplum-iOS-SDK/**',
            'OTHER_LDFLAGS' => '$(inherited) -framework "Leanplum"'
        }
    end

    s.subspec 'DefaultVersion' do |ss|
        ss.ios.dependency 'Leanplum-iOS-SDK', '1.3.11'
        s.subspec_common(ss)
    end

    s.subspec 'UserDefinedVersion' do |ss|
        ss.ios.dependency 'Leanplum-iOS-SDK'
        s.subspec_common(ss)
    end
end

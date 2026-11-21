Pod::Spec.new do |s|
  s.name           = 'ReisArama'
  s.version        = '1.0.0'
  s.summary        = 'Reis ajan araması (CallKit)'
  s.description    = 'Ajanla sesli arama için CallKit tabanlı arama arayüzü.'
  s.license        = 'PolyForm-Noncommercial-1.0.0'
  s.author         = 'gokhangeo'
  s.homepage       = 'https://github.com/gokhangeo/openbot'
  s.platforms      = { :ios => '16.4' }
  s.swift_version  = '5.9'
  s.source         = { git: '' }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.frameworks = 'CallKit', 'AVFoundation'
  s.source_files = "**/*.swift"
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }
end

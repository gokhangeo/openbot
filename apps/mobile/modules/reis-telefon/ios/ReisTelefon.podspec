# Reis (gokhangeo/openbot fork) eklentisi: ajanların istediği telefon işleri.
Pod::Spec.new do |s|
  s.name           = 'ReisTelefon'
  s.version        = '1.0.0'
  s.summary        = 'Reis telefon eylemleri'
  s.description    = 'Arama, SMS/WhatsApp taslağı, alarm, zamanlayıcı, hatırlatıcı, takvim, uygulama açma, Spotify ve yol tarifi.'
  s.license        = 'PolyForm-Noncommercial-1.0.0'
  s.author         = 'gokhangeo'
  s.homepage       = 'https://github.com/gokhangeo/openbot'
  s.platforms      = { :ios => '16.4' }
  s.swift_version  = '5.9'
  s.source         = { git: '' }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.frameworks = 'Contacts', 'ContactsUI', 'EventKit', 'MessageUI'
  s.weak_frameworks = 'AlarmKit'
  s.source_files = "**/*.swift"
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }
end

Pod::Spec.new do |s|
  s.name             = 'kidverse_ar'
  s.version          = '0.1.0'
  s.summary          = 'KidVerse AR capability plugin'
  s.description      = <<-DESC
  Minimal capability query for ARKit/ARCore.
  DESC
  s.homepage         = 'https://kidverse.local'
  s.license          = { :type => 'MIT', :text => 'MIT' }
  s.author           = { 'KidVerse' => 'dev@kidverse.local' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.platform     = :ios, '13.0'
  s.swift_version = '5.0'
  s.dependency 'Flutter'
  s.frameworks = 'ARKit'
  s.static_framework = true
end


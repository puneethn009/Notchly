require 'xcodeproj'

project_path = '/Users/puneeth/Documents/NotchApp/NotchApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add entitlements file reference to Xcode project if not present
# Xcode 16 uses PBXFileSystemSynchronizedRootGroup so we don't need to manually add files to groups.


# Swift packages
# KeyboardShortcuts
pkg1 = Xcodeproj::Project::Object::XCRemoteSwiftPackageReference.new(project, project.generate_uuid)
pkg1.repositoryURL = 'https://github.com/sindresorhus/KeyboardShortcuts.git'
pkg1.requirement = { "kind" => "upToNextMajorVersion", "minimumVersion" => "2.0.0" }
project.root_object.package_references << pkg1

# LaunchAtLogin-Modern
pkg2 = Xcodeproj::Project::Object::XCRemoteSwiftPackageReference.new(project, project.generate_uuid)
pkg2.repositoryURL = 'https://github.com/sindresorhus/LaunchAtLogin-Modern.git'
pkg2.requirement = { "kind" => "upToNextMajorVersion", "minimumVersion" => "1.0.0" }
project.root_object.package_references << pkg2

# Defaults
pkg3 = Xcodeproj::Project::Object::XCRemoteSwiftPackageReference.new(project, project.generate_uuid)
pkg3.repositoryURL = 'https://github.com/sindresorhus/Defaults.git'
pkg3.requirement = { "kind" => "upToNextMajorVersion", "minimumVersion" => "8.0.0" }
project.root_object.package_references << pkg3

# Sparkle
pkg4 = Xcodeproj::Project::Object::XCRemoteSwiftPackageReference.new(project, project.generate_uuid)
pkg4.repositoryURL = 'https://github.com/sparkle-project/Sparkle.git'
pkg4.requirement = { "kind" => "upToNextMajorVersion", "minimumVersion" => "2.6.0" }
project.root_object.package_references << pkg4

# Add package dependencies to target
[pkg1, pkg2, pkg3, pkg4].each do |pkg|
  dep = Xcodeproj::Project::Object::XCSwiftPackageProductDependency.new(project, project.generate_uuid)
  if pkg.repositoryURL.include?('KeyboardShortcuts')
    dep.product_name = 'KeyboardShortcuts'
  elsif pkg.repositoryURL.include?('LaunchAtLogin-Modern')
    dep.product_name = 'LaunchAtLogin'
  elsif pkg.repositoryURL.include?('Defaults')
    dep.product_name = 'Defaults'
  elsif pkg.repositoryURL.include?('Sparkle')
    dep.product_name = 'Sparkle'
  end
  dep.package = pkg
  target.package_product_dependencies << dep
end

# Update build settings
target.build_configurations.each do |config|
  # Deployment target
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  
  # Sandbox OFF, Hardened Runtime ON
  config.build_settings['ENABLE_APP_SANDBOX'] = 'NO'
  config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
  
  # Entitlements
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'NotchApp/NotchApp.entitlements'
  
  # Info.plist Keys (Since GENERATE_INFOPLIST_FILE = YES)
  config.build_settings['INFOPLIST_KEY_LSUIElement'] = 'YES'
  config.build_settings['INFOPLIST_KEY_NSScreenCaptureUsageDescription'] = 'NotchApp needs screen access to create PiP windows for any app.'
  config.build_settings['INFOPLIST_KEY_NSAccessibilityUsageDescription'] = 'NotchApp needs accessibility access for system-wide keyboard shortcuts.'
  config.build_settings['INFOPLIST_KEY_NSAppleEventsUsageDescription'] = 'NotchApp uses Apple Events for app integration features.'
  
  # Required to see Sparkle and others if needed
end

# Save the project
project.save
puts "Xcode project successfully updated!"

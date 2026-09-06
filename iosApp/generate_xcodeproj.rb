#!/usr/bin/env ruby
# Generates iosApp.xcodeproj from the same intent as project.yml (XcodeGen spec).
# Used because Homebrew/XcodeGen can't be installed on macOS 12 anymore; this uses the
# `xcodeproj` gem (CocoaPods' project manipulation library) instead.
#
#   gem install --user-install xcodeproj
#   ruby generate_xcodeproj.rb
#
# Regenerate whenever project.yml changes; keep the two in sync.

require "xcodeproj"
require "fileutils"

root      = File.expand_path(__dir__)
proj_path = File.join(root, "iosApp.xcodeproj")
src_dir   = File.join(root, "iosApp")

FileUtils.rm_rf(proj_path)

project = Xcodeproj::Project.new(proj_path)

target = project.new_target(:application, "iosApp", :ios, "16.0")

# --- source group + files -----------------------------------------------------
group = project.main_group.new_group("iosApp", "iosApp")
Dir.glob(File.join(src_dir, "**", "*.swift")).sort.each do |f|
  target.add_file_references([group.new_reference(f)])
end
# Info.plist is referenced, not compiled.
group.new_reference(File.join(src_dir, "Info.plist"))
group.new_reference(File.join(src_dir, "iosApp.entitlements"))
# Asset catalog -> resources build phase (add_resources detects .xcassets).
target.add_resources([group.new_reference(File.join(src_dir, "Assets.xcassets"))])
# Bundled preset audio (welcome / switch / goodbye greeting clips).
audio_group = group.new_group("PresetAudio", "PresetAudio")
Dir.glob(File.join(src_dir, "PresetAudio", "*.mp3")).sort.each do |f|
  target.add_resources([audio_group.new_reference(f)])
end

# Firebase config, if present (gitignored - see FirebaseConfig.swift). Bundled as a resource
# so Bundle.main can read it at runtime.
gsi = File.join(src_dir, "GoogleService-Info.plist")
target.add_resources([group.new_reference(gsi)]) if File.exist?(gsi)

# --- build settings (mirror project.yml) ------------------------------------
common = {
  "PRODUCT_BUNDLE_IDENTIFIER"    => "com.dialect.voice.ios",
  "INFOPLIST_FILE"               => "iosApp/Info.plist",
  "CODE_SIGN_ENTITLEMENTS"       => "iosApp/iosApp.entitlements",
  "SWIFT_VERSION"                => "5.0",
  "TARGETED_DEVICE_FAMILY"       => "1",
  "IPHONEOS_DEPLOYMENT_TARGET"   => "16.0",
  "GENERATE_INFOPLIST_FILE"      => "NO",
  "CODE_SIGNING_ALLOWED"         => "NO",   # simulator builds; flip on for device
  "CODE_SIGNING_REQUIRED"        => "NO",
  "ASSETCATALOG_COMPILER_APPICON_NAME" => "AppIcon",
  # KMP shared framework wiring (standard JetBrains template)
  "FRAMEWORK_SEARCH_PATHS"       => '$(inherited) $(SRCROOT)/../shared/build/xcode-frameworks/$(CONFIGURATION)/$(SDK_NAME)',
  "OTHER_LDFLAGS"                => '$(inherited) -framework Shared',
}
target.build_configurations.each do |config|
  config.build_settings.merge!(common)
end

# --- run script: build + embed the Kotlin shared framework -------------------
phase = target.new_shell_script_build_phase("Build shared framework (KMP)")
phase.shell_script = %(cd "$SRCROOT/.."\n./gradlew :shared:embedAndSignAppleFrameworkForXcode\n)
phase.always_out_of_date = "1"   # runs every build (mirrors basedOnDependencyAnalysis: false)
# Must run before Swift compiles.
target.build_phases.unshift(target.build_phases.delete(phase))

# --- scheme ------------------------------------------------------------------
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)
scheme.save_as(proj_path, "iosApp", true)

puts "Generated #{proj_path}"

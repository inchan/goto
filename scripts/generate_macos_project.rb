#!/usr/bin/env ruby

require "fileutils"
require "rubygems"
require "json"

gem "xcodeproj", ">= 1.27.0"
require "xcodeproj"

ROOT = File.expand_path("..", __dir__)
PROJECT_PATH = File.join(ROOT, "macos", "Goto.xcodeproj")
PACKAGE_VERSION = JSON.parse(File.read(File.join(ROOT, "package.json"))).fetch("version").split(/[+-]/).first

def add_file(target, group, path)
  file = group.new_file(path)
  target.add_file_references([file])
end

def add_resource(target, group, path)
  file = group.new_file(path)
  target.resources_build_phase.add_file_reference(file, true)
end

def add_framework(project, target, framework_name)
  path = "System/Library/Frameworks/#{framework_name}"
  file = project.frameworks_group.files.find { |ref| ref.path == path } || project.frameworks_group.new_file(path)
  target.frameworks_build_phase.add_file_reference(file, true)
end

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes["LastUpgradeCheck"] = "1520"
project.root_object.attributes["TargetAttributes"] ||= {}

app_target = project.new_target(:application, "Goto", :osx, "13.0")
extension_target = project.new_target(:app_extension, "GotoFinderSync", :osx, "13.0")

groups = {
  "Goto" => project.main_group.find_subpath("Goto", true),
  "FinderBridge" => project.main_group.find_subpath("FinderBridge", true),
  "GotoFinderSync" => project.main_group.find_subpath("GotoFinderSync", true),
  "Shared" => project.main_group.find_subpath("Shared", true),
  "NativeCore" => project.main_group.find_subpath("NativeCore", true),
  "Resources" => project.main_group.find_subpath("Resources", true),
}

app_sources = %w[
  Goto/GotoApp.swift
  Goto/MenuBarViewModel.swift
  Goto/SettingsWindow.swift
  FinderBridge/FinderLaunchBridge.swift
  Shared/FinderLaunchNotifications.swift
  ../native/Sources/GotoNativeCore/ProjectEntry.swift
  ../native/Sources/GotoNativeCore/RegistryStore.swift
  ../native/Sources/GotoNativeCore/ValidatedDirectory.swift
  ../native/Sources/GotoNativeCore/FinderSelection.swift
  ../native/Sources/GotoNativeCore/FinderErrorPresenter.swift
  ../native/Sources/GotoNativeCore/TerminalScriptBuilder.swift
  ../native/Sources/GotoNativeCore/TerminalLaunchError.swift
  ../native/Sources/GotoNativeCore/TerminalLaunchRequest.swift
  ../native/Sources/GotoNativeCore/TerminalLauncher.swift
  ../native/Sources/GotoNativeCore/TerminalApp.swift
  ../native/Sources/GotoNativeCore/TerminalAppDetector.swift
  ../native/Sources/GotoNativeCore/RegistryWatcher.swift
  ../native/Sources/GotoNativeCore/FinderClickMode.swift
  ../native/Sources/GotoNativeCore/SharedSettings.swift
].freeze

extension_sources = %w[
  GotoFinderSync/GotoFinderSyncExtension.swift
  Shared/FinderLaunchNotifications.swift
  ../native/Sources/GotoNativeCore/FinderClickMode.swift
].freeze

app_sources.each do |path|
  group =
    if path.include?("Goto/")
      groups["Goto"]
    elsif path.include?("FinderBridge/")
      groups["FinderBridge"]
    elsif path.include?("Shared/")
      groups["Shared"]
    else
      groups["NativeCore"]
    end
  add_file(app_target, group, path)
end

extension_sources.each do |path|
  group = path.include?("GotoFinderSync/") ? groups["GotoFinderSync"] : (path.include?("Shared/") ? groups["Shared"] : groups["NativeCore"])
  add_file(extension_target, group, path)
end

add_resource(app_target, groups["Resources"], "Resources/Goto.icns")

app_target.build_configurations.each do |config|
  config.build_settings["INFOPLIST_FILE"] = "Goto/Info.plist"
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "dev.goto.finder"
  config.build_settings["PRODUCT_NAME"] = "Goto"
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["MACOSX_DEPLOYMENT_TARGET"] = "13.0"
  config.build_settings["CODE_SIGN_STYLE"] = "Manual"
  config.build_settings["CODE_SIGN_IDENTITY"] = "-"
  config.build_settings["GENERATE_INFOPLIST_FILE"] = "NO"
  config.build_settings["MARKETING_VERSION"] = PACKAGE_VERSION
  config.build_settings["CURRENT_PROJECT_VERSION"] = PACKAGE_VERSION
  config.build_settings["LD_RUNPATH_SEARCH_PATHS"] = "$(inherited) @executable_path/../Frameworks @executable_path/../PlugIns"
  config.build_settings["ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES"] = "YES"
end

extension_target.build_configurations.each do |config|
  config.build_settings["INFOPLIST_FILE"] = "GotoFinderSync/Info.plist"
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "dev.goto.finder.findersync"
  config.build_settings["PRODUCT_NAME"] = "GotoFinderSync"
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["MACOSX_DEPLOYMENT_TARGET"] = "13.0"
  config.build_settings["CODE_SIGN_STYLE"] = "Manual"
  config.build_settings["CODE_SIGN_IDENTITY"] = "-"
  config.build_settings["GENERATE_INFOPLIST_FILE"] = "NO"
  config.build_settings["MARKETING_VERSION"] = PACKAGE_VERSION
  config.build_settings["CURRENT_PROJECT_VERSION"] = PACKAGE_VERSION
  config.build_settings["CODE_SIGN_ENTITLEMENTS"] = "GotoFinderSync/GotoFinderSync.entitlements"
  config.build_settings["APPLICATION_EXTENSION_API_ONLY"] = "YES"
  config.build_settings["SKIP_INSTALL"] = "YES"
  config.build_settings["LD_RUNPATH_SEARCH_PATHS"] = "$(inherited) @executable_path/../../Frameworks @executable_path/../../PlugIns"
end

project.root_object.attributes["TargetAttributes"][app_target.uuid] = {}
project.root_object.attributes["TargetAttributes"][extension_target.uuid] = {}

add_framework(project, app_target, "FinderSync.framework")
add_framework(project, extension_target, "FinderSync.framework")

embed_phase = app_target.new_copy_files_build_phase("Embed App Extensions")
embed_phase.dst_subfolder_spec = "13"
build_file = embed_phase.add_file_reference(extension_target.product_reference, true)
build_file.settings = { "ATTRIBUTES" => %w[RemoveHeadersOnCopy CodeSignOnCopy] }
app_target.add_dependency(extension_target)

project.save

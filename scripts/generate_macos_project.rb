#!/usr/bin/env ruby

require "fileutils"
require "rubygems"
require "json"

gem "xcodeproj", ">= 1.27.0"
require "xcodeproj"

ROOT = File.expand_path("..", __dir__)
PROJECT_PATH = File.join(ROOT, "product", "macos", "Goto.xcodeproj")
PACKAGE_VERSION = JSON.parse(File.read(File.join(ROOT, "product", "cli", "package.json"))).fetch("version").split(/[+-]/).first

def add_file(target, group, path)
  file = group.new_file(path)
  target.add_file_references([file])
end

def add_resource(target, group, path)
  file = group.new_file(path)
  target.resources_build_phase.add_file_reference(file, true)
end

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes["LastUpgradeCheck"] = "1520"
project.root_object.attributes["TargetAttributes"] ||= {}

app_target = project.new_target(:application, "Goto", :osx, "13.0")
finder_sync_target = project.new_target(:app_extension, "GotoFinderSync", :osx, "13.0")

groups = {
  "Goto" => project.main_group.find_subpath("Goto", true),
  "GotoFinderSync" => project.main_group.find_subpath("GotoFinderSync", true),
  "NativeCore" => project.main_group.find_subpath("NativeCore", true),
  "Resources" => project.main_group.find_subpath("Resources", true),
}

app_sources = %w[
  Goto/GotoApp.swift
  Goto/MenuBarViewModel.swift
  Goto/SettingsWindow.swift
  ../core/Sources/GotoNativeCore/ProjectEntry.swift
  ../core/Sources/GotoNativeCore/RegistryStore.swift
  ../core/Sources/GotoNativeCore/ValidatedDirectory.swift
  ../core/Sources/GotoNativeCore/TerminalErrorPresenter.swift
  ../core/Sources/GotoNativeCore/TerminalScriptBuilder.swift
  ../core/Sources/GotoNativeCore/TerminalLaunchError.swift
  ../core/Sources/GotoNativeCore/TerminalLaunchRequest.swift
  ../core/Sources/GotoNativeCore/TerminalLauncher.swift
  ../core/Sources/GotoNativeCore/TerminalApp.swift
  ../core/Sources/GotoNativeCore/TerminalAppDetector.swift
  ../core/Sources/GotoNativeCore/RegistryWatcher.swift
].freeze

app_sources.each do |path|
  group = path.include?("Goto/") ? groups["Goto"] : groups["NativeCore"]
  add_file(app_target, group, path)
end

finder_sync_sources = %w[
  GotoFinderSync/GotoFinderSyncExtension.swift
  ../core/Sources/GotoNativeCore/ValidatedDirectory.swift
  ../core/Sources/GotoNativeCore/FinderFolderResolver.swift
  ../core/Sources/GotoNativeCore/LaunchDebouncer.swift
  ../core/Sources/GotoNativeCore/TerminalErrorPresenter.swift
  ../core/Sources/GotoNativeCore/TerminalScriptBuilder.swift
  ../core/Sources/GotoNativeCore/TerminalLaunchError.swift
  ../core/Sources/GotoNativeCore/TerminalLaunchRequest.swift
  ../core/Sources/GotoNativeCore/TerminalLauncher.swift
  ../core/Sources/GotoNativeCore/TerminalApp.swift
  ../core/Sources/GotoNativeCore/TerminalAppDetector.swift
].freeze

finder_sync_sources.each do |path|
  group = path.start_with?("GotoFinderSync/") ? groups["GotoFinderSync"] : groups["NativeCore"]
  add_file(finder_sync_target, group, path)
end

add_resource(app_target, groups["Resources"], "Resources/Goto.icns")

[app_target, finder_sync_target].each do |target|
  target.build_configurations.each do |config|
    config.build_settings["MARKETING_VERSION"] = PACKAGE_VERSION
    config.build_settings["CURRENT_PROJECT_VERSION"] = PACKAGE_VERSION
    config.build_settings["SWIFT_VERSION"] = "5.0"
    config.build_settings["MACOSX_DEPLOYMENT_TARGET"] = "13.0"
    config.build_settings["CODE_SIGN_STYLE"] = "Manual"
    config.build_settings["CODE_SIGN_IDENTITY"] = "-"
    config.build_settings["GENERATE_INFOPLIST_FILE"] = "NO"
  end
end

app_target.build_configurations.each do |config|
  config.build_settings["INFOPLIST_FILE"] = "Goto/Info.plist"
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "dev.goto.app"
  config.build_settings["PRODUCT_NAME"] = "Goto"
  config.build_settings["LD_RUNPATH_SEARCH_PATHS"] = "$(inherited) @executable_path/../Frameworks"
  config.build_settings["ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES"] = "YES"
end

finder_sync_target.build_configurations.each do |config|
  config.build_settings["INFOPLIST_FILE"] = "GotoFinderSync/Info.plist"
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "dev.goto.app.findersync"
  config.build_settings["PRODUCT_NAME"] = "GotoFinderSync"
  config.build_settings["APPLICATION_EXTENSION_API_ONLY"] = "YES"
  config.build_settings["SKIP_INSTALL"] = "YES"
  config.build_settings["ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES"] = "YES"
end

app_target.add_dependency(finder_sync_target)
embed_extensions = app_target.new_copy_files_build_phase("Embed App Extensions")
embed_extensions.symbol_dst_subfolder_spec = :plug_ins
embed_extensions.dst_path = ""
embed_extensions.add_file_reference(finder_sync_target.product_reference, true)

project.root_object.attributes["TargetAttributes"][app_target.uuid] = {}
project.root_object.attributes["TargetAttributes"][finder_sync_target.uuid] = {}
project.save

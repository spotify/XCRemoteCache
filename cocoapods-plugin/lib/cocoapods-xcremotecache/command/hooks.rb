# Copyright 2021 Spotify AB
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'cocoapods'
require 'cocoapods/resolver'
require 'open-uri'
require 'yaml'
require 'json'
require 'pathname'


module CocoapodsXCRemoteCacheModifier
  # Registers for CocoaPods plugin hooks
  module Hooks
    BIN_DIR = '.rc'
    LLDB_INIT_COMMENT="#RemoteCacheCustomSourceMap"
    LLDB_INIT_PATH = "#{ENV['HOME']}/.lldbinit"
    FAT_ARCHIVE_NAME_INFIX = 'arm64-x86_64'
    XCRC_COOCAPODS_ROOT_KEY = 'XCRC_COOCAPODS_ROOT'

    # List of plugins' user properties that should not be copied to .rcinfo
    CUSTOM_CONFIGURATION_KEYS = [
      'enabled',
      'xcrc_location',
      'exclude_targets',
      'exclude_build_configurations',
      'final_target',
      'check_build_configuration',
      'check_platform',
      'modify_lldb_init',
      'fake_src_root',
      'exclude_sdks_configurations'
    ]

    class XCRemoteCache
      @@configuration = nil

      def self.configure(c)
        @@configuration = c
      end

      def self.set_configuration_default_values
        default_values = {
          'mode' => 'consumer',
          'enabled' => true,
          'xcrc_location' => "XCRC",
          'exclude_build_configurations' => [],
          'check_build_configuration' => 'Debug',
          'check_platform' => 'iphonesimulator',
          'modify_lldb_init' => true,
          'xccc_file' => "#{BIN_DIR}/xccc",
          'remote_commit_file' => "#{BIN_DIR}/arc.rc",
          'exclude_targets' => [],
          'prettify_meta_files' => false,
          'fake_src_root' => "/#{'x' * 10 }",
          'disable_certificate_verification' => false,
          'custom_rewrite_envs' => [],
          'exclude_sdks_configurations' => []
        }
        @@configuration.merge! default_values.select { |k, v| !@@configuration.key?(k) }
        # Always include XCRC_COOCAPODS_ROOT_KEY in custom_rewrite_envs
        unless @@configuration['custom_rewrite_envs'].include?(XCRC_COOCAPODS_ROOT_KEY)
          @@configuration['custom_rewrite_envs'] << XCRC_COOCAPODS_ROOT_KEY
        end
      end

      def self.validate_configuration()
        required_values = [
          'cache_addresses',
          'primary_repo',
          'check_build_configuration',
          'check_platform'
        ]

        missing_configuration_values = required_values.select { |v| !@@configuration.key?(v) }
        unless missing_configuration_values.empty?
          throw "XCRemoteCache not fully configured. Make sure all required fields are provided. Missing fields are: #{missing_configuration_values.join(', ')}."
        end

        mode = @@configuration['mode']
        unless mode == 'consumer' || mode == 'producer' || mode == 'producer-fast'
          throw "Incorrect 'mode' value. Allowed values are ['consumer', 'producer', 'producer-fast'], but you provided '#{mode}'. A typo?"
        end

        unless mode == 'consumer' || @@configuration.key?('final_target')
          throw "Missing 'final_target' value in the Pod configuration."
        end
      end

      def self.generate_rcinfo()
        @@configuration.select { |key, value| !CUSTOM_CONFIGURATION_KEYS.include?(key) }
      end

      def self.parent_dir(path, parent_count)
        "../" * parent_count + path
      end

      # @param target [Target] target to apply XCRemoteCache
      # @param repo_distance [Integer] distance from the git repo root to the target's $SRCROOT
      # @param xc_location [String] path to the dir with all XCRemoteCache binaries, relative to the repo root
      # @param xc_cc_path [String] path to the XCRemoteCache clang wrapper, relative to the repo root
      # @param mode [String] mode name ('consumer', 'producer', 'producer-fast' etc.)
      # @param exclude_build_configurations [String[]] list of targets that should have disabled remote cache
      # @param final_target [String] name of target that should trigger marking
      # @param exclude_sdks_configurations [String[]] list of sdks that should have disabled remote cache
      def self.enable_xcremotecache(
        target,
        repo_distance,
        xc_location,
        xc_cc_path,
        mode,
        exclude_build_configurations,
        final_target,
        fake_src_root,
        exclude_sdks_configurations,
        enable_swift_driver_integration
      )
        srcroot_relative_xc_location = parent_dir(xc_location, repo_distance)
        # location of the entrite CocoaPods project, relative to SRCROOT
        srcroot_relative_project_location = parent_dir('', repo_distance)

        target.build_configurations.each do |config|
          # apply only for relevant Configurations
          next if exclude_build_configurations.include?(config.name)
          if mode == 'consumer'
            reset_build_setting(config.build_settings, 'CC', "$SRCROOT/#{parent_dir(xc_cc_path, repo_distance)}", exclude_sdks_configurations)
          elsif mode == 'producer' || mode == 'producer-fast'
            config.build_settings.delete('CC') if config.build_settings.key?('CC')
          end
          swiftc_name = enable_swift_driver_integration ? 'swiftc' : 'xcswiftc'
          reset_build_setting(config.build_settings, 'SWIFT_EXEC', "$SRCROOT/#{srcroot_relative_xc_location}/#{swiftc_name}", exclude_sdks_configurations)
          reset_build_setting(config.build_settings, 'LIBTOOL', "$SRCROOT/#{srcroot_relative_xc_location}/xclibtool", exclude_sdks_configurations)
          # Setting LIBTOOL to '' breaks SwiftDriver intengration so resetting it to the original value 'libtool' for all excluded configurations
          add_build_setting_for_sdks(config.build_settings, 'LIBTOOL', 'libtool', exclude_sdks_configurations)
          reset_build_setting(config.build_settings, 'LD', "$SRCROOT/#{srcroot_relative_xc_location}/xcld", exclude_sdks_configurations)
          reset_build_setting(config.build_settings, 'LDPLUSPLUS', "$SRCROOT/#{srcroot_relative_xc_location}/xcldplusplus", exclude_sdks_configurations)
          reset_build_setting(config.build_settings, 'LIPO', "$SRCROOT/#{srcroot_relative_xc_location}/xclipo", exclude_sdks_configurations)
          reset_build_setting(config.build_settings, 'SWIFT_USE_INTEGRATED_DRIVER', 'NO', exclude_sdks_configurations) unless enable_swift_driver_integration

          reset_build_setting(config.build_settings, 'XCREMOTE_CACHE_FAKE_SRCROOT', fake_src_root, exclude_sdks_configurations)
          reset_build_setting(config.build_settings, 'XCRC_PLATFORM_PREFERRED_ARCH', "$(LINK_FILE_LIST_$(CURRENT_VARIANT)_$(PLATFORM_PREFERRED_ARCH):dir:standardizepath:file:default=arm64)", exclude_sdks_configurations)
          reset_build_setting(config.build_settings, XCRC_COOCAPODS_ROOT_KEY, "$SRCROOT/#{srcroot_relative_project_location}", exclude_sdks_configurations)
          debug_prefix_map_replacement = '$(SRCROOT' + ':dir:standardizepath' * repo_distance + ')'
          add_cflags!(config.build_settings, '-fdebug-prefix-map', "#{debug_prefix_map_replacement}=$(XCREMOTE_CACHE_FAKE_SRCROOT)", exclude_sdks_configurations)
          add_swiftflags!(config.build_settings, '-debug-prefix-map', "#{debug_prefix_map_replacement}=$(XCREMOTE_CACHE_FAKE_SRCROOT)", exclude_sdks_configurations)
          delete_build_setting(config.build_settings, 'XCRC_DISABLED')
          add_build_setting_for_sdks(config.build_settings, 'XCRC_DISABLED', 'YES', exclude_sdks_configurations)
        end

        # Prebuild
        if mode == 'consumer'
          existing_prebuild_script = target.build_phases.detect do |phase|
            if phase.respond_to?(:name)
              phase.name != nil && phase.name.start_with?("[XCRC] Prebuild")
            end
          end

          prebuild_script = existing_prebuild_script || target.new_shell_script_build_phase("[XCRC] Prebuild #{target.name}")
          prebuild_script.shell_script = "\"$SCRIPT_INPUT_FILE_0\""
          prebuild_script.input_paths = ["$SRCROOT/#{srcroot_relative_xc_location}/xcprebuild"]
          prebuild_script.output_paths = [
            "$(TARGET_TEMP_DIR)/rc.enabled",
            "$(DWARF_DSYM_FOLDER_PATH)/$(DWARF_DSYM_FILE_NAME)"
          ]
          prebuild_script.dependency_file = "$(TARGET_TEMP_DIR)/prebuild.d"

          # Move prebuild (last element) to the position before compile sources phase (to make it real 'prebuild')
          if !existing_prebuild_script
            compile_phase_index = target.build_phases.index(target.source_build_phase)
            target.build_phases.insert(compile_phase_index, target.build_phases.delete(prebuild_script))
          end
        elsif mode == 'producer' || mode == 'producer-fast'
          # Delete existing prebuild build phase (to support switching between modes)
          target.build_phases.delete_if do |phase|
            if phase.respond_to?(:name)
              phase.name != nil && phase.name.start_with?("[XCRC] Prebuild")
            end
          end
        end

        # Postbuild
        existing_postbuild_script = target.build_phases.detect do |phase|
          if phase.respond_to?(:name)
            phase.name != nil && phase.name.start_with?("[XCRC] Postbuild")
          end
        end
        postbuild_script = existing_postbuild_script || target.new_shell_script_build_phase("[XCRC] Postbuild #{target.name}")
        postbuild_script.shell_script = "\"$SCRIPT_INPUT_FILE_0\""
        postbuild_script.input_paths = ["$SRCROOT/#{srcroot_relative_xc_location}/xcpostbuild"]
        postbuild_script.output_paths = [
          "$(TARGET_BUILD_DIR)/$(MODULES_FOLDER_PATH)/$(PRODUCT_MODULE_NAME).swiftmodule/$(XCRC_PLATFORM_PREFERRED_ARCH).swiftmodule.md5",
          "$(TARGET_BUILD_DIR)/$(MODULES_FOLDER_PATH)/$(PRODUCT_MODULE_NAME).swiftmodule/$(XCRC_PLATFORM_PREFERRED_ARCH)-$(LLVM_TARGET_TRIPLE_VENDOR)-$(SWIFT_PLATFORM_TARGET_PREFIX)$(LLVM_TARGET_TRIPLE_SUFFIX).swiftmodule.md5"
        ]
        postbuild_script.dependency_file = "$(TARGET_TEMP_DIR)/postbuild.d"
        # Move postbuild (last element) to the position after compile sources phase (to make it real 'postbuild')
        if !existing_postbuild_script
          compile_phase_index = target.build_phases.index(target.source_build_phase)
          target.build_phases.insert(compile_phase_index + 1, target.build_phases.delete(postbuild_script))
        end

        # Mark a sha as ready for a given platform and configuration when building the final_target
        if (mode == 'producer' || mode == 'producer-fast') && target.name == final_target
          existing_mark_script = target.build_phases.detect do |phase|
            if phase.respond_to?(:name)
              phase.name != nil && phase.name.start_with?("[XCRC] Mark")
            end
          end
          mark_script = existing_mark_script || target.new_shell_script_build_phase("[XCRC] Mark")
          mark_script.shell_script = "\"$SCRIPT_INPUT_FILE_0\" mark --configuration \"$CONFIGURATION\" --platform $PLATFORM_NAME"
          mark_script.input_paths = ["$SRCROOT/#{srcroot_relative_xc_location}/xcprepare"]
        else
          # Delete existing mark build phase (to support switching between modes or changing the final target)
          target.build_phases.delete_if do |phase|
            if phase.respond_to?(:name)
              phase.name != nil && phase.name.start_with?("[XCRC] Mark")
            end
          end
        end
      end

      def self.disable_xcremotecache_for_target(target)
        target.build_configurations.each do |config|
          config.build_settings.delete('CC') if config.build_settings.key?('CC')
          config.build_settings.delete('SWIFT_EXEC') if config.build_settings.key?('SWIFT_EXEC')
          config.build_settings.delete('LIBTOOL') if config.build_settings.key?('LIBTOOL')
          config.build_settings.delete('LIPO') if config.build_settings.key?('LIPO')
          config.build_settings.delete('LD') if config.build_settings.key?('LD')
          config.build_settings.delete('LDPLUSPLUS') if config.build_settings.key?('LDPLUSPLUS')
          config.build_settings.delete('SWIFT_USE_INTEGRATED_DRIVER') if config.build_settings.key?('SWIFT_USE_INTEGRATED_DRIVER')
          # Remove Fake src root for ObjC & Swift
          config.build_settings.delete('XCREMOTE_CACHE_FAKE_SRCROOT')
          config.build_settings.delete('XCRC_PLATFORM_PREFERRED_ARCH')
          config.build_settings.delete(XCRC_COOCAPODS_ROOT_KEY)
          remove_cflags!(config.build_settings, '-fdebug-prefix-map')
          remove_swiftflags!(config.build_settings, '-debug-prefix-map')
        end

        # User project is not generated from scratch (contrary to `Pods`), delete all previous XCRemoteCache phases
        target.build_phases.delete_if {|phase|
          # Some phases (e.g. PBXSourcesBuildPhase) don't have strict name check respond_to?
          if phase.respond_to?(:name)
              phase.name != nil && phase.name.start_with?("[XCRC]")
          end
        }
      end

      # Writes XCRemoteCache info in the specified directory location
      def self.save_rcinfo(info, directory)
          File.open(File.join(directory, '.rcinfo'), 'w') { |file| file.write info.to_yaml }
      end

      def self.download_xcrc_if_needed(local_location)
        required_binaries = ['xcld', 'xcldplusplus', 'xclibtool', 'xclipo', 'xcpostbuild', 'xcprebuild', 'xcprepare', 'xcswiftc']
        binaries_exist = required_binaries.reduce(true) do |exists, filename|
          file_path = File.join(local_location, filename)
          exists = exists && File.exist?(file_path)
        end

        # Don't download XCRemoteCache if provided directory already contains it
        return if binaries_exist

        Dir.mkdir(local_location) unless File.exist?(local_location)
        local_package_location = File.join(local_location, 'package.zip')

        download_latest_xcrc_release(local_package_location)

        if !system("unzip #{local_package_location} -d #{local_location}")
          throw "Unzipping XCRemoteCache failed"
        end
      end

      def self.download_latest_xcrc_release(local_package_location)
        release_url = 'https://api.github.com/repos/spotify/XCRemoteCache/releases/latest'
        asset_url = nil

        URI.open(release_url) do |f|
          assets_array = JSON.parse(f.read)['assets']
          # Pick fat archive
          asset_array = assets_array.detect{|arr| arr['name'].include?(FAT_ARCHIVE_NAME_INFIX)}
          asset_url = asset_array['url']
        end

        if asset_url.nil?
          throw "Downloading XCRemoteCache failed"
        end

        URI.open(asset_url, "accept" => 'application/octet-stream') do |f|
          File.open(local_package_location, "wb") do |file|
            file.puts f.read
          end
        end
      end

      def self.add_cflags!(options, key, value, exclude_sdks_configurations)
        reset_build_setting(options, 'OTHER_CFLAGS', remove_cflags!(options, key) << "#{key}=#{value}", exclude_sdks_configurations)
      end

      def self.remove_cflags!(options, key)
        cflags_arr = options.fetch('OTHER_CFLAGS', ['$(inherited)'])
        cflags_arr = [cflags_arr] if cflags_arr.kind_of? String
        options['OTHER_CFLAGS'] = cflags_arr.delete_if {|flag| flag.include?("#{key}=") }
        options['OTHER_CFLAGS']
      end

      def self.add_swiftflags!(options, key, value, exclude_sdks_configurations)
        reset_build_setting(options, 'OTHER_SWIFT_FLAGS', remove_swiftflags!(options, key) + " #{key} #{value}", exclude_sdks_configurations)
      end

      def self.remove_swiftflags!(options, key)
        options['OTHER_SWIFT_FLAGS'] = options.fetch('OTHER_SWIFT_FLAGS', '$(inherited)').gsub(/\s+#{Regexp.escape(key)}\s+\S+/, '')
        options['OTHER_SWIFT_FLAGS']
      end

      def self.add_build_setting(build_settings, key, value, exclude_sdks_configurations)
        build_settings[key] = value
        for exclude_sdks_configuration in exclude_sdks_configurations
          build_settings["#{key}[sdk=#{exclude_sdks_configuration}]"] = [""]
        end
      end

      # Deletes all previous build settings for a key, and sets a new value to all configurations
      # but the sdks in exclude_sdks_configurations
      def self.reset_build_setting(build_settings, key, value, exclude_sdks_configurations)
        delete_build_setting(build_settings, key)
        add_build_setting(build_settings, key, value, exclude_sdks_configurations)
      end

      # Delete all build setting for a key, including settings like "[skd=*,arch=*]"
      def self.delete_build_setting(build_settings, key)
        for build_setting_key in build_settings.keys
          build_settings.delete(build_setting_key) if build_setting_key == key || build_setting_key.start_with?("#{key}[")
        end
      end

      # Sets value for a key only for a subset of sdk configurations
      def self.add_build_setting_for_sdks(build_settings, key, value, sdk_configurations)
        for sdk_configuration in sdk_configurations
          build_settings["#{key}[sdk=#{sdk_configuration}]"] = value
        end
      end

      # Uninstall the XCRemoteCache
      def self.disable_xcremotecache(user_project, pods_project = nil)
        user_project.targets.each do |target|
          disable_xcremotecache_for_target(target)
        end
        user_project.save()

        unless pods_project.nil?
          pods_project.native_targets.each do |target|
            disable_xcremotecache_for_target(target)
          end
          pods_proj_directory = pods_project.project_dir
          pods_project.root_object.project_references.each do |subproj_ref|
            generated_project = Xcodeproj::Project.open("#{pods_proj_directory}/#{subproj_ref[:project_ref].path}")
            generated_project.native_targets.each do |target|
              disable_xcremotecache_for_target(target)
            end
            generated_project.save()
          end
          pods_project.save()
        end

        # Remove .lldbinit rewrite
        save_lldbinit_rewrite(nil,nil) unless !@@configuration['modify_lldb_init']
      end

      # Returns the content (array of lines) of the lldbinit with stripped XCRemoteCache rewrite
      def self.clean_lldbinit_content(lldbinit_path)
        all_lines = []
        return all_lines unless File.exist?(lldbinit_path)
        File.open(lldbinit_path) { |file|
          while(line = file.gets) != nil
            line = line.strip
            if line == LLDB_INIT_COMMENT
              # skip current and next lines
              file.gets
              next
            end
            all_lines << line
          end
        }
        all_lines
      end

      # Append source rewrite command to the lldbinit content
      def self.add_lldbinit_rewrite(lines_content, user_proj_directory,fake_src_root)
        all_lines = lines_content.clone
        all_lines << LLDB_INIT_COMMENT
        all_lines << "settings set target.source-map #{fake_src_root} #{user_proj_directory}"
        all_lines << ""
        all_lines
      end

      def self.save_lldbinit_rewrite(user_proj_directory,fake_src_root)
        lldbinit_lines = clean_lldbinit_content(LLDB_INIT_PATH)
        lldbinit_lines = add_lldbinit_rewrite(lldbinit_lines, user_proj_directory,fake_src_root) unless user_proj_directory.nil?
        File.write(LLDB_INIT_PATH, lldbinit_lines.join("\n"), mode: "w")
      end

      Pod::HooksManager.register('cocoapods-xcremotecache', :pre_install) do |installer_context|
        # The main responsibility of that hook is forcing Pods regeneration when XCRemoteCache is enabled for the first time
        # In the post_install hook, this plugin adds extra build settings and steps to all Pods targets, but only when XCRemoteCache
        # is enabled and all artifacts are available (i.e. xcprepare returns 0).
        # If Pods projects/targets are cached from previous `pod install` action that didn't enable XCRemoteCache (e.g. artifacts
        # are not available in the remote cache), these projects/targets should be invalidated to include XCRemoteCache-related
        # build steps and build settings.
        if @@configuration.nil?
          Pod::UI.puts "[XCRC] Warning! XCRemoteCache not configured. Call xcremotecache({...}) in Podfile to enable XCRemoteCache"
          next
        end

        begin
          # `user_pod_directory`` and `user_proj_directory` in the 'postinstall' should be equal
          user_pod_directory = File.dirname(installer_context.podfile.defined_in_file)
          set_configuration_default_values

          unless @@configuration['enabled']
            # No need to check if enabling remote cache for the first time
            next
          end

          validate_configuration()
          mode = @@configuration['mode']
          remote_commit_file = @@configuration['remote_commit_file']
          xcrc_location = @@configuration['xcrc_location']
          check_build_configuration = @@configuration['check_build_configuration']
          check_platform = @@configuration['check_platform']

          xcrc_location_absolute = "#{user_pod_directory}/#{xcrc_location}"
          remote_commit_file_absolute = "#{user_pod_directory}/#{remote_commit_file}"

          # Download XCRC
          download_xcrc_if_needed(xcrc_location_absolute)

          # Save .rcinfo
          root_rcinfo = generate_rcinfo()
          save_rcinfo(root_rcinfo, user_pod_directory)

          # Create directory for xccc & arc.rc location
          Dir.mkdir(BIN_DIR) unless File.exist?(BIN_DIR)

          # Remove previous xccc & arc.rc
          was_previously_enabled = File.exist?(remote_commit_file_absolute)
          File.delete(remote_commit_file_absolute) if File.exist?(remote_commit_file_absolute)

          prepare_result = YAML.load`#{xcrc_location_absolute}/xcprepare --configuration #{check_build_configuration} --platform #{check_platform}`
          if !prepare_result['result'] && mode == 'consumer'
            # Remote cache is still disabled - no need to force Pods projects/targets regeneration
            next
          end

          # Force rebuilding all Pods project, because XCRC build steps and settings need to be added to Pods project/targets
          # It is relevant only when 'incremental_installation' is enabled, otherwise installed_cache_path does not exist on a disk
          installed_cache_path = installer_context.sandbox.project_installation_cache_path
          if !was_previously_enabled && File.exist?(installed_cache_path)
            Pod::UI.puts "[XCRC] Forces Pods project regenerations because XCRC is enabled for the first time."
            File.delete(installed_cache_path)
          end
        end
      end

      Pod::HooksManager.register('cocoapods-xcremotecache', :post_install) do |installer_context|
        if @@configuration.nil?
          next
        end

        user_project = installer_context.umbrella_targets[0].user_project

        begin
          user_proj_directory = File.dirname(user_project.path)
          set_configuration_default_values

          unless @@configuration['enabled']
            Pod::UI.puts "[XCRC] XCRemoteCache disabled"
            disable_xcremotecache(user_project)
            next
          end

          validate_configuration()
          mode = @@configuration['mode']
          xccc_location = @@configuration['xccc_file']
          remote_commit_file = @@configuration['remote_commit_file']
          xcrc_location = @@configuration['xcrc_location']
          exclude_targets = @@configuration['exclude_targets'] || []
          exclude_build_configurations = @@configuration['exclude_build_configurations'] || []
          final_target = @@configuration['final_target']
          check_build_configuration = @@configuration['check_build_configuration']
          check_platform = @@configuration['check_platform']
          fake_src_root = @@configuration['fake_src_root']
          exclude_sdks_configurations = @@configuration['exclude_sdks_configurations'] || []
          enable_swift_driver_integration = @@configuration['enable_swift_driver_integration'] || false

          xccc_location_absolute = "#{user_proj_directory}/#{xccc_location}"
          xcrc_location_absolute = "#{user_proj_directory}/#{xcrc_location}"

          # Save .rcinfo
          root_rcinfo = generate_rcinfo()
          save_rcinfo(root_rcinfo, user_proj_directory)

          # Remove previous xccc
          File.delete(xccc_location_absolute) if File.exist?(xccc_location_absolute)

          # Prepare XCRC

          # Pods projects can be generated only once (if incremental_installation is enabled)
          # Always integrate XCRemoteCache to all Pods, in case it will be needed later
          unless installer_context.pods_project.nil?
            # Attach XCRemoteCache to Pods targets
            # Enable only for native targets which can have compilation steps
            installer_context.pods_project.native_targets.each do |target|
                next if target.source_build_phase.files_references.empty?
                next if target.name.start_with?("Pods-")
                next if target.name.end_with?("Tests")
                next if exclude_targets.include?(target.name)
                enable_xcremotecache(target, 1, xcrc_location, xccc_location, mode, exclude_build_configurations, final_target,fake_src_root, exclude_sdks_configurations, enable_swift_driver_integration)
            end

            # Create .rcinfo into `Pods` directory as that .xcodeproj reads configuration from .xcodeproj location
            pods_proj_directory = installer_context.sandbox_root

            # Attach XCRemoteCache to Generated Pods projects
            installer_context.pods_project.root_object.project_references.each do |subproj_ref|
                generated_project = Xcodeproj::Project.open("#{pods_proj_directory}/#{subproj_ref[:project_ref].path}")
                generated_project.native_targets.each do |target|
                    next if target.source_build_phase.files_references.empty?
                    next if target.name.end_with?("Tests")
                    next if exclude_targets.include?(target.name)
                    enable_xcremotecache(target, 1, xcrc_location, xccc_location, mode, exclude_build_configurations, final_target,fake_src_root, exclude_sdks_configurations, enable_swift_driver_integration)
                end
                generated_project.save()
            end

            # Manual Pods/.rcinfo generation

            # all paths in .rcinfo are relative to the root so paths used in Pods.xcodeproj need to be aligned
            pods_path = Pathname.new(pods_proj_directory)
            root_path = Pathname.new(user_proj_directory)
            root_path_to_pods = root_path.relative_path_from(pods_path)

            pods_rcinfo = root_rcinfo.merge({
              'remote_commit_file' => "#{root_path_to_pods}/#{remote_commit_file}",
              'xccc_file' => "#{root_path_to_pods}/#{xccc_location}"
            })
            save_rcinfo(pods_rcinfo, pods_proj_directory)

            installer_context.pods_project.save()
          end

          # Enabled/disable XCRemoteCache for the main (user) project
          begin
            # TODO: Do not compile xcc again. `xcprepare` compiles it in pre-install anyway
            prepare_result = YAML.load`#{xcrc_location_absolute}/xcprepare --configuration #{check_build_configuration} --platform #{check_platform}`
            unless prepare_result['result'] || mode != 'consumer'
              # Uninstall the XCRemoteCache for the consumer mode
              disable_xcremotecache(user_project, installer_context.pods_project)
              Pod::UI.puts "[XCRC] XCRemoteCache disabled - no artifacts available"
              next
            end
          rescue => error
            disable_xcremotecache(user_project, installer_context.pods_project)
            Pod::UI.puts "[XCRC] XCRemoteCache failed with an error: #{error}."
            next
          end


          # Attach XCRC to the app targets
          user_project.targets.each do |target|
              next if exclude_targets.include?(target.name)
              enable_xcremotecache(target, 0, xcrc_location, xccc_location, mode, exclude_build_configurations, final_target,fake_src_root, exclude_sdks_configurations, enable_swift_driver_integration)
          end

          # Set Target sourcemap
          if @@configuration['modify_lldb_init']
            save_lldbinit_rewrite(user_proj_directory,fake_src_root)
          else
            Pod::UI.puts "[XCRC] lldbinit modification is disabled. Debugging may behave weirdly"
            Pod::UI.puts "[XCRC] put \"settings set target.source-map #{fake_src_root} \#{your_project_directory}\" to your \".lldbinit\" "
          end

          user_project.save()
          Pod::UI.puts "[XCRC] XCRemoteCache enabled"
        rescue Exception => e
          Pod::UI.puts "[XCRC] XCRemoteCache disabled with error: #{e}"
          puts e.full_message(highlight: true, order: :top)
          disable_xcremotecache(user_project, installer_context.pods_project)
        end
      end
    end
  end
end

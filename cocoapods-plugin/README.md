# cocoapods-xcremotecache

The CocoaPods plugin that integrates XCRemoteCache with the project.

## Installation

### Using RubyGems

```bash
gem install cocoapods-xcremotecache
```

### From sources

Build & install the plugin

```bash
gem build cocoapods-xcremotecache.gemspec
gem install cocoapods-xcremotecache-{CurrentGemVersion}.gem # e.g. gem install cocoapods-xcremotecache-0.0.1.gem
```

## Usage

1. Add plugin reference to your project `Podfile`:
```
plugin 'cocoapods-xcremotecache'
```
2. Configure XCRemoteCache at the top of your `Podfile` definition:
```ruby
xcremotecache({
    'cache_addresses' => ['http://localhost:8080/cache/pods'], 
    'primary_repo' => 'https://your.primary.repo.git',
    'mode' => 'consumer'
})
```
3. (Optional) Unzip all XCRemoteCache binaries to the `xcrc_location` directory (defaults to `XCRC` placed next to the `Podfile`). If you don't provide all binaries in the location, the plugin will try to download the latest XCRemoteCache artifact from the public GitHub page.
4. Call `pod install` and verify that `[XCRC] XCRemoteCache enabled` has been printed to the console.

### Configuration parameters

An object that is passed to the `xcremotecache` can contain all properties supported natively in the XCRemoteCache. In addition to that, there are extra parameters that are unique to the `cocoapods-xcremotecache`:

| Parameter | Description | Default | Required |
| ------------- | ------------- | ------------- | ------------- |
| `enabled` | A Boolean value that enables XCRemoteCache integration to the project | `true` | ⬜️ |
| `xcrc_location` | The location of all XCRemoteCache binaries | `{podfile_dir}/XCRC` | ⬜️ |
| `exclude_targets` | Comma-separated list of targets that shouldn't use XCRemoteCache | `[]`| ⬜️ |
| `exclude_build_configurations` | Comma-separated list of configurations that shouldn't use XCRemoteCache | `[]`| ⬜️ |
| `final_target` | A target name that is build at the end of the build chain. Relevant only for a 'producer' mode to mark a given sha as ready to use from cache | `Debug` | ⬜️ |
| `check_build_configuration` | A build configuration for which the remote cache availability is performed. Relevant only for a 'consumer' mode | `Debug` | ⬜️ |
| `check_platform` | A platform for which the remote cache availability is performed. Relevant only for a 'consumer' mode | `iphonesimulator` | ⬜️ 
| `modify_lldb_init` | Controls if the pod integration should modify `~/.lldbinit` | `true` | ⬜️ |
| `xccc_file` | The path where should be placed the `xccc` binary (in the pod installation phase) | `{podfile_dir}/.rc/xccc` | ⬜️ |
| `remote_commit_file` | The path of the file with the remote commit sha (in the pod installation phase) | `{podfile_dir}/.rc/arc.rc`| ⬜️ |
| `prettify_meta_files` | A Boolean value that opts-in pretty JSON formatting for meta files | `false` | ⬜️ |
| `disable_certificate_verification` | A Boolean value that opts-in SSL certificate validation is disabled | `false` | ⬜️ |

## Uninstalling

To fully uninstall the plugin, call:

```bash
gem uninstall cocoapods-xcremotecache
```

## Limitations

* When `generate_multiple_pod_projects` mode is enabled, only first-party targets are cached by XCRemoteCache (all dependencies are compiled locally).

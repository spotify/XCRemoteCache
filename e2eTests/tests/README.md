### How to add a CocoaPods scenario

In order to run different test suites in cocoapods integration, you can create multiple `.Podfile` files as a "starting point" of the E2E test.

#### Files organization

1. File `{SUITE_NAME}.Podfile` contains a base Podfile that should be excercised
1. [Optional] File `{SUITE_NAME}.Podfile.config` contains a hash of extra xcremote-cache-plugin parameters that should be added to the `xcremotecache()` configuration in a podfile
1. [Optional] File `{SUITE_NAME}.Podfile.expectations` overrides a set of default validation steps that should be checked after consumer's build. Supported steps are: `hits`, `misses` or `hit_rate` (e.g. `100` for 100$). By default, 100% `hit_rate` and 0 `misses` are used  - if you want to skip a validation step for a given suite, you can set it to `null` in a hash

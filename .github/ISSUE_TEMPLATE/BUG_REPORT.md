---
name: ⚠️ Bug Report
about: Something isn't working as expected

---

<!--
PLEASE HELP US PROCESS GITHUB ISSUES FASTER BY PROVIDING THE FOLLOWING INFORMATION.
-->

**My integration setup**

[ ] CocoaPods cocoapods-xcremotecache plugin
[ ] Automatic integration wusingith `xcprepare integrate ...`
[ ] Manual integration
[ ] Carthage

**Expected/desired behavior**
<!-- Describe what the desired behavior would be. -->

**Minimal reproduction of the problem with instructions**
<!-- Please provide the *STEPS TO REPRODUCE*. -->

**Producer Logs**
<!-- Capture logs from 10 minutes: `log show --predicate 'sender BEGINSWITH "xc"' --style compact --info --debug -last 10m` -->

<details>
  <pre> [REPLACE THIS WITH YOUR INFORMATION] </pre>
</details>

**Consumer Logs**
<!-- Capture logs from 10 minutes: `log show --predicate 'sender BEGINSWITH "xc"' --style compact --info --debug -last 10m` -->

<details>
  <pre> [REPLACE THIS WITH YOUR INFORMATION] </pre>
</details>

**Pods/Carthage file**
<!-- Delete if you don't use CocoaPods or Carthage -->

<details>
  <pre> [REPLACE THIS WITH YOUR INFORMATION] </pre>
</details>

**Environment**

* **XCRemoteCache:** X.Y.Z
* **cocoapods-xcremotecache:** X.Y.Z <!-- check with `gem list cocoapods-xcremotecache` >
* **HTTP cache server:** ... <!-- e.g. demo docker, nginx, AWS etc. >
* **Xcode:** X.Y.Z

**Post build stats**
<!-- 
To capture build statistics: 
* call `xcprepare stats --reset` (or `XCRC/xcprepare stats --reset` for CocoaPods)
* Build a project in Xcode
* `xcprepare stats` (or `XCRC/xcprepare stats` for CocoaPods) 
-->

<details>
  <pre> [REPLACE THIS WITH YOUR INFORMATION] </pre>
</details>

**Others**
<!-- Anything else relevant?  Operating system version, , ... -->
# Continuous testing workflow

As part of the [development flow at OpenProject](../../../development/#branching-model-and-development-flow), proposed changes to the core application will be made through a GitHub pull request and the entire test suite is automatically evaluated on GitHub Actions. You will see the results as a status on your pull request.

You will likely start working with the OpenProject test suite through our continuous testing setup at [GitHub Actions](https://github.com/opf/openproject/actions). All pull requests and commits to the core repository will be tested by GitHub Actions.

Successful test suite runs are one requirement to see your changes merged.

## List failures

A failing status will look like the following on your pull request. You may need to click *Show all checks* to expand all checks to see the details link.

![Exemplary failing github actions test suite](github-broken-tests-pr.png)

Here you'll see that the *GitHub Actions* check has reported an error, which likely means that your pull request contains errors. It might also result from a [temporary error running the test suite](#tests-failing-on-github-actions-ci-and-passing-locally), or from a test that was broken in the `dev` branch.

The test suite is [run in parallel](../running-tests-locally/#parallel-testing) to save time. The overall run time of the test suite is around *15 minutes* on GitHub.

Click on the Details link to see the individual *jobs* that GitHub executes.

[Here's a link to an exemplary failed test run on GitHub](https://github.com/opf/openproject/pull/9355/checks?check_run_id=2730782867). In this case, one of the feature jobs has reported an error.

![Exemplary failed status details](github-broken-tests-pr-details1.png)

Click on each job and each step to show the [log output for this job](https://github.com/opf/openproject/pull/9355/checks?check_run_id=2730782867). It will contain more information about how many tests failed and will also temporarily provide a screenshot of the browser during the occurrence of the test failure (only if a browser was involved in testing).

In our example, multiple tests are reported as failing:

```shell
rspec ./spec/features/work_packages/pagination_spec.rb[1:1:1:1] # Work package pagination with project scope behaves like paginated work package list is expected not to have text "WorkPackage No. 23"
rspec ./spec/features/work_packages/pagination_spec.rb[1:2:1:1] # Work package pagination globally behaves like paginated work package list is expected not to have text "WorkPackage No. 29"
rspec ./spec/features/work_packages/timeline/timeline_navigation_spec.rb:131 # Work package timeline navigation can save the open state and zoom of timeline
rspec ./spec/features/work_packages/timeline/timeline_navigation_spec.rb:193 # Work package timeline navigation with a hierarchy being shown toggles the hierarchy in both views
rspec ./spec/features/work_packages/timeline/timeline_navigation_spec.rb:317 # Work package timeline navigation when table is grouped shows milestone icons on collapsed project group rows but not on expanded ones
```

![GitHub job log showing failing test](github-broken-tests.png)

### Diagnose failures

Once you know which tests are failing, run them locally to try and reproduce the failures. Having reproducible failures locally is the first step to diagnose and fix them.

How to do this depends on the kind of job that failed.

**Errors in the npm group**

An error in the *npm* group means you likely have broken an existing Angular component spec or added an invalid new one. Please see the [Frontend tests](../running-tests-locally/#frontend-tests) section on how to run them.

**Errors in the units group**

An error in the *units* group means there is a failing ruby unit test. Please see the [Unit tests](../running-tests-locally/#unit-tests) section on how to run these.

**Errors in the features group**

You will be able to run failing tests locally in a similar fashion for all errors reported in the `units` and `features` jobs. Please see the [System tests](../running-tests-locally/#system-tests) section for more information.

**Helper to extract all failing tests**

There is a small ruby script that will parse the logs of a GitHub Actions run and output all `rspec` tests that failed for you to run in one command.

```shell
./script/github_pr_errors
```

If you want to run the tests directly to rspec, you can use this command:

```shell
./script/github_pr_errors | xargs bundle exec rspec
```

### Tests failing on GitHub Actions CI and passing locally

Some tests can fail on GitHub actions CI, and pass locally which makes them harder to reproduce, diagnose, and fix.

Possible reasons are:

* Different configuration between CI environment and local environment
  * GitHub actions run with `CI=true` environment variable. This setting will eager load the app before running tests. As some classes may monkey patch parts of the code, the behavior can be different when the app is fully loaded.
    * Try running the tests with `CI=true`.
  * OpenProject configuration difference
    * Try changing or disabling any environment variables prefixed with `OPENPROJECT_` in your environment or `.env` files.
    * Try changing or removing `config/configuration.yml` settings under the `test:` key.
* Missing executables
  * Source control management tests may need `svnadmin` or `git` to execute properly.
  * LDAP tests may need `java` to spin up a LDAP server instance.
* Different test execution order
  * Parts of the OpenProject code are using memoization and caching for performance, and some tests can do weird things like prepending a module or other meta programming. Without proper clean up of the global state, subsequent tests may fail. It can go unnoticed depending on the test execution order.
  * RSpec tests order is different on each run. The order is defined by the random seed which can be set with `--seed` option. When running rspec, the random seed is displayed like this: `Randomized with seed 18352`.
  * Try running tests locally with the same random seed as the one used on CI.
    * Once you determined that the failure is order dependant, use [`--bisect`](https://rspec.info/features/3-12/rspec-core/command-line/bisect/) to isolate the minimal set of examples that reproduce the same failures.
* Faster / slower machine and race conditions
  * Some system tests using browser and performing ajax requests may not be synchronized with the test execution: the test is testing something that has not happened yet. Sometimes the ajax runs at the right time and the test passes, sometimes it runs at the wrong time and the test fails.
  * Use `script/bulk_run_rspec` to run the same test multiple times. If it has both failing and passing results, it means it is a flickering test.
  * To help diagnose why a system test is failing:
    * Browser screenshots are created for failing system tests involving a browser. You can find them in the job log output.
    * Try running with `OPENPROJECT_TESTING_NO_HEADLESS=1` to view what the browser is doing. Use `OPENPROJECT_TESTING_AUTO_DEVTOOLS=1` to have DevTools opened so that you can use `debugger` statements in the js code.
    * If the interactions are still too fast to understand why the test is failing, use `OPENPROJECT_TESTING_SLOWDOWN_FACTOR`, providing the number of seconds to slow down every browser command with. For example, if you'd like to slow down every interaction by 200 milliseconds, run with `OPENPROJECT_TESTING_SLOWDOWN_FACTOR=0.2`.
* Migration executed locally
  * While developing on another branch, you may run migrations and forget to roll them back when switching branches. This can lead to different test results: a migration modifying a database column default value can impact system behavior and change test results.
  * To find if this is your case, run `rails db:migrate:status` to list migration status. Look for `up    <migration-id>  ********** NO FILE **********` patterns. If you have some, try looking up the commit associated with this migration and check if it explains behavior difference.
  * To look up commits referencing the migration, use the `<migration-id>` from previous command and run `git log -p --all -- '**/*<migration-id>*'`. For instance `git log -p --all -- '**/*20220816065025*'`.
  * If you find a commit and want to roll the associated migration back:
    * Checkout the commit: `git switch --detach <commit-sha>`
    * Roll the migration back: `rails db:migrate:down VERSION=<migration-id>`
    * Switch back to where you left: `git switch -`

### Skip test execution on GitHub Actions CI

Sometimes, you know you're pushing changes to a pull request that you now are work in progress or are known to break existing or new tests.

To avoid additional test executions, you can include `[skip ci]` in your commit message to ensure GitHub Actions are not being triggered and skips your build. Please note that a successful merge of your pull request will require a green CI build.

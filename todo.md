# TODO

## Release feature

### ~~Release workflow performance — move large releases to a background job~~ (done)
Implemented: `VersionsController#release` validates synchronously, then runs releases with
more than `RELEASE_ASYNC_THRESHOLD` (100) incomplete work packages via
`Versions::ReleaseJob` so the web request is not blocked. Smaller releases still run
synchronously for immediate feedback. Tune `RELEASE_ASYNC_THRESHOLD` if needed.

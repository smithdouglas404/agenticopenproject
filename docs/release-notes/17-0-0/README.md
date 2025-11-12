---
title: OpenProject 17.0.0
sidebar_navigation:
    title: 17.0.0
release_version: 17.0.0
release_date: 2025-12-10
---

# OpenProject 17.0.0

Release date: 2025-12-10

TODO

## Important updates

TODO

## Important technical changes

## Major upgrade of background job processor good_job

OpenProject 17.0 upgraded to a new major version of `good_job`, its underlying processor for background jobs. This upgrade was already prepared with
OpenProject 15.3, so if you've had any version between 15.3 and 16.6 running in your environment, you should be safe to proceed to 17.0.
However, if you directly upgraded from a version before 15.3, make sure to at least leave the background workers running on version 16.6 for a few minutes,
so that they can process all pending jobs, before continuing the upgrade to 17.0.

## Bug fixes and changes

<!-- Warning: Anything within the below lines will be automatically removed by the release script -->
<!-- BEGIN AUTOMATED SECTION -->

<!-- END AUTOMATED SECTION -->
<!-- Warning: Anything above this line will be automatically removed by the release script -->

## Contributions

TODO

---
title: OpenProject 17.5.0
sidebar_navigation:
    title: 17.5.0
release_version: 17.5.0
release_date: 2026-06-10
---

 # OpenProject 17.5.0

 Release date: 2026-06-10

 TODO

<!-- BEGIN CVE AUTOMATED SECTION -->

<!-- END CVE AUTOMATED SECTION -->

## Important feature changes

TODO

## Important technical updates

### Session authentication relies on new header for non-GET requests

Previously when making session-authenticated requests to APIv3 endpoints, non-GET requests were only allowed when the
HTTP Header `X-Requested-With: XMLHttpRequest` was present. This header is usually associated with frameworks such as jQuery,
but is also added for all requests originating from the OpenProject frontend still. For session authentication it served the
purpose of preventing cross-site request forgery, e.g. through simple HTTP forms.

The usage of this header has now been replaced with a check for `Sec-Fetch-Site: same-origin`, which is added by a browser automatically
to requests and also can't be added or altered through JavaScript. It's unlikely that this causes any disruptions, because session authentication
should only be used for browser-contexts, where the new header will still be present. Non-browser API-access should use different authentication
methods (e.g. OAuth or API tokens), which are not affected by this change.

## Bug fixes and changes

<!-- Warning: Anything within the below lines will be automatically removed by the release script -->
<!-- BEGIN AUTOMATED SECTION -->

<!-- END AUTOMATED SECTION -->
<!-- Warning: Anything above this line will be automatically removed by the release script -->

## Contributions

TODO


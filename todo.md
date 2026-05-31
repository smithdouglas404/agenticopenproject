# TODO

## Release feature

### Release workflow performance — move large releases to a background job
`Versions::ReleaseService` (the "Release" action: roll-forward / decouple) updates each
affected work package individually and synchronously (`affected_work_packages.find_each`
→ per-work-package `save`), so every work package incurs its own query, save and journal
within the request.

For releases with many incomplete work packages this can be slow or time out. It should
run in a background job (consistent with how OpenProject handles bulk work-package
operations), reporting progress/result asynchronously, rather than blocking the request.

- Source: `app/services/versions/release_service.rb` (`apply_strategy` / `rewrite_release_links`).
- Acceptance: releasing a release with a large number of incomplete work packages does not
  block the web request; the moves are still validated-by-construction and journaled.
- Note: this is a known, accepted limitation for the initial release of the feature
  (flagged in self-review, Medium severity).

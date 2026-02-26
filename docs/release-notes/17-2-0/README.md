---
title: OpenProject 17.2.0
sidebar_navigation:
    title: 17.2.0
release_version: 17.2.0
release_date: 2026-02-26
---

 # OpenProject 17.2.0

 Release date: 2026-02-26

 We released OpenProject [OpenProject 17.2.0](https://community.openproject.org/versions/2246).
 The release contains several bug fixes and we recommend updating to the newest version.
 In these Release Notes, we will give an overview of important feature changes. At the end, you will find a complete list of all changes and bug fixes.

<!-- BEGIN CVE AUTOMATED SECTION -->

<!-- END CVE AUTOMATED SECTION -->

## Important feature changes

<!-- Inform about the major features in this section -->

## Important updates and breaking changes

<!-- Remove this section if empty, add to it in pull requests linking to tickets and provide information -->

<!--more-->

## Bug fixes and changes

<!-- Warning: Anything within the below lines will be automatically removed by the release script -->
<!-- BEGIN AUTOMATED SECTION -->

- Feature: Reusable meeting templates for meeting agendas \[[#35642](https://community.openproject.org/wp/35642)\]
- Feature: Export relationship columns in PDF report \[[#66000](https://community.openproject.org/wp/66000)\]
- Feature: Overview widget for Budgets \[[#66124](https://community.openproject.org/wp/66124)\]
- Feature: Comment fields for project attributes \[[#66343](https://community.openproject.org/wp/66343)\]
- Feature: Make project description and status widget editable on Overview tab \[[#67690](https://community.openproject.org/wp/67690)\]
- Feature: Implement token refreshing and reduce token expiration time \[[#68460](https://community.openproject.org/wp/68460)\]
- Feature: Display custom field type on form  \[[#68524](https://community.openproject.org/wp/68524)\]
- Feature: MCP Server Infrastructure and Metadata Endpoint \[[#68683](https://community.openproject.org/wp/68683)\]
- Feature: Integrate MCP Authentication with OpenProject OAuth2 \[[#68685](https://community.openproject.org/wp/68685)\]
- Feature: Provide initial set of MCP Tools \[[#68686](https://community.openproject.org/wp/68686)\]
- Feature: Expose OpenProject APIv3 Entities as MCP Resources \[[#68689](https://community.openproject.org/wp/68689)\]
- Feature: Add Admin Page for MCP Configuration \[[#68690](https://community.openproject.org/wp/68690)\]
- Feature: Standardized inplace edit fields based on Primer \[[#68832](https://community.openproject.org/wp/68832)\]
- Feature: Add enterprise banner for MCP server \[[#70086](https://community.openproject.org/wp/70086)\]
- Feature: Primerize Custom Field forms \[[#70292](https://community.openproject.org/wp/70292)\]
- Feature: Support WebP images in PDF exports \[[#70333](https://community.openproject.org/wp/70333)\]
- Feature: Use autocompleters in Admin/Backlogs page \[[#71069](https://community.openproject.org/wp/71069)\]
- Feature: Improve Accessibility of Project Overview and Dashboard Widgets \[[#71075](https://community.openproject.org/wp/71075)\]
- Feature: Allow to use API Keys as Bearer tokens \[[#71147](https://community.openproject.org/wp/71147)\]
- Feature: Allow requiring to be logged in for external links \[[#71624](https://community.openproject.org/wp/71624)\]
- Feature: Primerize versions project settings \[[#71641](https://community.openproject.org/wp/71641)\]
- Feature: Primerize groups administration \[[#71642](https://community.openproject.org/wp/71642)\]
- Feature: Rename &quot;Enable REST web service&quot; setting \[[#71886](https://community.openproject.org/wp/71886)\]
- Feature: Reduce page size of MCP responses \[[#71977](https://community.openproject.org/wp/71977)\]
- Feature: Allow to configure MCP tool response volume \[[#71978](https://community.openproject.org/wp/71978)\]
- Feature: Allow authentication to MCP endpoint via session cookie \[[#72253](https://community.openproject.org/wp/72253)\]
- Feature: Enable Column Sorting on Versions Overview \[[#72354](https://community.openproject.org/wp/72354)\]
- Feature: MCP Server as a bridge between OpenProject and LLMs \[[#62781](https://community.openproject.org/wp/62781)\]
- Bugfix: Children column on WP list cannot be expanded \[[#64491](https://community.openproject.org/wp/64491)\]
- Bugfix: DPA/AVV cannot be downloaded \[[#67323](https://community.openproject.org/wp/67323)\]
- Bugfix: BlockNote: Color for text not applied from the block side menu \[[#67507](https://community.openproject.org/wp/67507)\]
- Bugfix: Mobile web: When deep linking to a comment the comment is not fully scrolled into view \[[#68221](https://community.openproject.org/wp/68221)\]
- Bugfix: Updating the activity anchor URL without a page load does not highlight the relevant target element \[[#68262](https://community.openproject.org/wp/68262)\]
- Bugfix: Documents index page: pagination per page options overflow on mobile \[[#68533](https://community.openproject.org/wp/68533)\]
- Bugfix: Changing the filter on the activity tab with a large number of comments and slow network/compute lacks loading state while waiting for request completion \[[#68878](https://community.openproject.org/wp/68878)\]
- Bugfix: Flickering spec ./modules/meeting/spec/features/structured\_meetings/work\_package\_meetings\_tab\_spec.rb:392 \[[#68952](https://community.openproject.org/wp/68952)\]
- Bugfix: Clicking work package tabs triggers page reload and flickering \[[#69210](https://community.openproject.org/wp/69210)\]
- Bugfix: Label for the admin document types reflects &quot;priorities&quot; instead of &quot;types&quot; in it&#39;s messaging \[[#69304](https://community.openproject.org/wp/69304)\]
- Bugfix: Infinite SAML Seeding Loop Causing Disk Space Exhaustion \[[#69339](https://community.openproject.org/wp/69339)\]
- Bugfix: &quot;Show attachments in the files tab by default&quot; potentially overwrites the setting for existing project \[[#69991](https://community.openproject.org/wp/69991)\]
- Bugfix: Fix accessibility errors found by ERB Lint \[[#70166](https://community.openproject.org/wp/70166)\]
- Bugfix: Missing list items when using checkboxes in tables \[[#70537](https://community.openproject.org/wp/70537)\]
- Bugfix: Documents: when document content exceeds vertical height, the cursor does not scroll into view unless there is content typed \[[#70791](https://community.openproject.org/wp/70791)\]
- Bugfix: Helm-Chart: Allow user to provide service specific annotations \[[#71055](https://community.openproject.org/wp/71055)\]
- Bugfix: Activity tab overflows with long names \[[#71106](https://community.openproject.org/wp/71106)\]
- Bugfix: Multi-user custom field requires clicking twice in order to be in focus \[[#71135](https://community.openproject.org/wp/71135)\]
- Bugfix: Status translation issue on status widget \[[#71137](https://community.openproject.org/wp/71137)\]
- Bugfix: Unnecessary empty journals on dragging work packages with automatic subjects \[[#71421](https://community.openproject.org/wp/71421)\]
- Bugfix: Sending mails via sendmail does not work \[[#71447](https://community.openproject.org/wp/71447)\]
- Bugfix: Error Content-Security-Policy with Hocuspocus integration due to URL scheme misconfiguration \[[#71888](https://community.openproject.org/wp/71888)\]
- Bugfix: BlockNote Extension: Click on WP title opens new tab and redirects the current tab \[[#71898](https://community.openproject.org/wp/71898)\]
- Bugfix: Connection error on successive navigation to and from a document \[[#71901](https://community.openproject.org/wp/71901)\]
- Bugfix: Impossible to search for archived projects, page reverts to active projects list on its own \[[#71971](https://community.openproject.org/wp/71971)\]
- Bugfix: Remove presenter field/participants references in onetime templates \[[#72222](https://community.openproject.org/wp/72222)\]
- Bugfix: Space is too small for placeholder text in Backlogs module \[[#72366](https://community.openproject.org/wp/72366)\]
- Bugfix: Missing caption in new template dialog \[[#72375](https://community.openproject.org/wp/72375)\]
- Bugfix: Wrong wording in Enterprise on-prem support token input field \[[#72459](https://community.openproject.org/wp/72459)\]

<!-- END AUTOMATED SECTION -->
<!-- Warning: Anything above this line will be automatically removed by the release script -->

## Contributions
A very special thank you goes to our sponsors for this release.
Also a big thanks to our Community members for reporting bugs and helping us identify and provide fixes.
Special thanks for reporting and finding bugs go to Holger Schantin, Stefan Weiberg, Jure Uršič, Natalie Stettner, Romain Besson.

Last but not least, we are very grateful for our very engaged translation contributors on Crowdin, who translated quite a few OpenProject strings!
Would you like to help out with translations yourself?
Then take a look at our translation guide and find out exactly how you can contribute.
It is very much appreciated!


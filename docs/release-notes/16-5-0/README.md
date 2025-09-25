---
title: OpenProject 16.5.0
sidebar_navigation:
    title: 16.5.0
release_version: 16.5.0
release_date: 2025-10-08
---

# OpenProject 16.5.0

Release date: 2025-10-08

We released [OpenProject 16.5.0](https://community.openproject.org/versions/2215). The release contains several bug fixes and we recommend updating to the newest version. In these Release Notes, we will give an overview of important feature changes. At the end, you will find a complete list of all changes and bug fixes.

## Important feature changes

### Add work packages to a meeting section in the Meetings tab

Text

Screenshot

### Choose color mode more conveniently with “Increase contrast” checkboxes

Text

Screenshot


### Filter projects by last update

Text

Screenshot


### Jump to highlighted target elements from deep links

Text

Screenshot


### Confirm critical actions with more accessible danger dialogs

Text

Screenshot

### Consistent entering of hours in duration fields

Text

### Add/remove projects from favorite via the API

Text


## Important technical updates

<!-- Remove this section if empty, add to it in pull requests linking to tickets and provide information -->

<!--more-->

## Bug fixes and changes

<!-- Warning: Anything within the below lines will be automatically removed by the release script -->
<!-- BEGIN AUTOMATED SECTION -->

- Bugfix: Work package exports fails for queries using custom fields not enabled for filtering \[[#40119](https://community.openproject.org/wp/40119)\]
- Bugfix: Spent time widget: No rounding \[[#56505](https://community.openproject.org/wp/56505)\]
- Bugfix: i18n for english translation not loading for requests \[[#59238](https://community.openproject.org/wp/59238)\]
- Bugfix: User is not taken to the Edit page after creating a custom field \[[#59359](https://community.openproject.org/wp/59359)\]
- Bugfix: PDF Gantt export potentially exports huge date ranges \[[#60585](https://community.openproject.org/wp/60585)\]
- Bugfix: Wrong Time and costs menu item path \[[#60613](https://community.openproject.org/wp/60613)\]
- Bugfix: Possible to create, update and delete relations to work package for which user does not have permission to manage relations \[[#61438](https://community.openproject.org/wp/61438)\]
- Bugfix: I18n::ArgumentError in WorkPackages::ProgressController#edit \[[#62075](https://community.openproject.org/wp/62075)\]
- Bugfix: Adding or removing successor in relations tab is not correctly reflected in Gantt chart \[[#63437](https://community.openproject.org/wp/63437)\]
- Bugfix: Project identifier cannot be updated if a required project attribute is created \[[#63668](https://community.openproject.org/wp/63668)\]
- Bugfix: Image not visible in PDF export \[[#64356](https://community.openproject.org/wp/64356)\]
- Bugfix: Possible to deactivate the default work package priority \[[#64842](https://community.openproject.org/wp/64842)\]
- Bugfix: Characters &quot;eaten&quot; when modifying duration in work package date picker \[[#65132](https://community.openproject.org/wp/65132)\]
- Bugfix: WP items in bulk delete modal are misaligned \[[#65417](https://community.openproject.org/wp/65417)\]
- Bugfix: Plan name in enterprise banners has insufficient color contrast \[[#65507](https://community.openproject.org/wp/65507)\]
- Bugfix: Second line of breadcrumb is not properly left-aligned on non-mobile/desktop viewports \[[#65635](https://community.openproject.org/wp/65635)\]
- Bugfix: Poor performance on a number of API endpoints (i.e. slow work package table) \[[#65718](https://community.openproject.org/wp/65718)\]
- Bugfix: Error when exporting wp table grouped by project phase \[[#65740](https://community.openproject.org/wp/65740)\]
- Bugfix: &quot;Start new timer&quot; button not displayed in mobile view \[[#65907](https://community.openproject.org/wp/65907)\]
- Bugfix: WP menu sticks to the top of the browser window if WP type list is long \[[#66092](https://community.openproject.org/wp/66092)\]
- Bugfix: Validation of essential OIDC claims causes server error when failing \[[#66289](https://community.openproject.org/wp/66289)\]
- Bugfix: Large amount of comments causes workpackage to freeze (missing lazy-loading and loading indicator for Activity tab) \[[#66552](https://community.openproject.org/wp/66552)\]
- Bugfix: ID link in notification center always points to last opened project \[[#66751](https://community.openproject.org/wp/66751)\]
- Bugfix: Removing widgets from Projects Overview page is very slow/unresponsive \[[#66753](https://community.openproject.org/wp/66753)\]
- Bugfix: Activity shows changes to admin only custom fields also to non admin users \[[#66925](https://community.openproject.org/wp/66925)\]
- Bugfix: LDAP Groupsync settings can&#39;t be edited in synced LDAP group \[[#66941](https://community.openproject.org/wp/66941)\]
- Bugfix: Do not use unspecified ServiceProviderConfig.AuthenticationSchemes.type \[[#67055](https://community.openproject.org/wp/67055)\]
- Bugfix: Work packages export dialog description attribute dragger locale \[[#67181](https://community.openproject.org/wp/67181)\]
- Bugfix: Incorrect terminology in docs and UI: &quot;Favored&quot; vs &quot;Favorited&quot; \[[#67312](https://community.openproject.org/wp/67312)\]
- Bugfix: Cost reports month locale \[[#67466](https://community.openproject.org/wp/67466)\]
- Bugfix: Project overview click zone doesn&#39;t react to clicking + displays wrong cursor type \[[#67470](https://community.openproject.org/wp/67470)\]
- Bugfix: It is possible to change custom field format by providing different format to update action \[[#67521](https://community.openproject.org/wp/67521)\]
- Bugfix: Primerized login dropdown does not autofocus on input fields \[[#67602](https://community.openproject.org/wp/67602)\]
- Bugfix: Virus scanning is not triggered after uploading a file to S3 storage \[[#67664](https://community.openproject.org/wp/67664)\]
- Feature: Consistent entering of hours in duration fields \[[#61367](https://community.openproject.org/wp/61367)\]
- Feature: Advanced accessibility for the Danger Dialogs (with ARIA semantics to communicate contextual changes) \[[#61890](https://community.openproject.org/wp/61890)\]
- Feature: Advanced work package meeting selector \[[#62265](https://community.openproject.org/wp/62265)\]
- Feature: Highlight the relevant target element when the user gets to a page via a deep link  \[[#62712](https://community.openproject.org/wp/62712)\]
- Feature: Redesign the &quot;My Account / Session management&quot; page using Primer \[[#65412](https://community.openproject.org/wp/65412)\]
- Feature: Extend link\_translate helper to use localized links \[[#66253](https://community.openproject.org/wp/66253)\]
- Feature: Add &quot;Increase contrast&quot; checkboxes for &quot;Light high contrast&quot; and &quot;Dark high contrast&quot; that force high contrast in Automatic mode \[[#66396](https://community.openproject.org/wp/66396)\]
- Feature: Publish release candidates on docker hub \[[#67165](https://community.openproject.org/wp/67165)\]
- Feature: Update the Getting started video linked in the application help menu \[[#67176](https://community.openproject.org/wp/67176)\]
- Feature: Update help menu and widget on start page in application \[[#67177](https://community.openproject.org/wp/67177)\]
- Feature: Update Enterprise plan text in widget on application start page \[[#67178](https://community.openproject.org/wp/67178)\]
- Feature: Add/remove projects from favourite via the API \[[#67241](https://community.openproject.org/wp/67241)\]
- Feature: Hide segmented control and include sub-itmes checkbox of the filterable tree view \[[#67541](https://community.openproject.org/wp/67541)\]

<!-- END AUTOMATED SECTION -->
<!-- Warning: Anything above this line will be automatically removed by the release script -->

## Contributions

A very special thank you goes to Helmholtz-Zentrum Berlin, City of Cologne, Deutsche Bahn and ZenDiS for sponsoring released or upcoming features. Your support, alongside the efforts of our amazing Community, helps drive these innovations. Also a big thanks to our Community members for reporting bugs and helping us identify and provide fixes. Special thanks for reporting and finding bugs go to Alexander Aleschenko, Lars Tiedemann, Akihiko Fujikawa, and Johannes Baumgarten.

Last but not least, we are very grateful for our very engaged translation contributors on Crowdin, who translated quite a few OpenProject strings! This release we would like to particularly thank the following users:

- [name](https://crowdin.com/profile/name), for a great number of translations into Language.
- 

Would you like to help out with translations yourself? Then take a look at our [translation guide](../../contributions-guide/translate-openproject/) and find out exactly how you can contribute. It is very much appreciated!


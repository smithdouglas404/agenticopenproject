---
title: OpenProject 16.4.0
sidebar_navigation:
    title: 16.4.0
release_version: 16.4.0
release_date: 2025-08-27
---

# OpenProject 16.4.0

Release date: 2025-08-27

We released OpenProject [OpenProject 16.4.0](https://community.openproject.org/versions/2211).
The release contains several bug fixes and we recommend updating to the newest version.
In these Release Notes, we will give an overview of important feature changes. At the end, you will find a complete list of all changes and bug fixes.

## Important feature changes

<!-- Inform about the major features in this section -->

## Important updates and breaking changes

<!-- Remove this section if empty, add to it in pull requests linking to tickets and provide information -->

<!--more-->

## Bug fixes and changes

<!-- Warning: Anything within the below lines will be automatically removed by the release script -->
<!-- BEGIN AUTOMATED SECTION -->

- Feature: Search-based selection of participants in meetings for projects with very many project members \[[#37009](https://community.openproject.org/wp/37009)\]
- Feature: Project attribute of type &quot;Factor list&quot; \[[#50111](https://community.openproject.org/wp/50111)\]
- Feature: Synchronize group information based on claims in the OIDC userinfo \[[#58408](https://community.openproject.org/wp/58408)\]
- Feature: A single &#39;My Meetings&#39; iCal calendar subscription action so users can always have their calendars in sync with the meetings \[[#63463](https://community.openproject.org/wp/63463)\]
- Feature: Implement Enterprise banners for SSO login admin page and add to correct token \[[#63572](https://community.openproject.org/wp/63572)\]
- Feature: Create a FilterableTreeView component \[[#63717](https://community.openproject.org/wp/63717)\]
- Feature: SSO as separate authentication settings tab \[[#63819](https://community.openproject.org/wp/63819)\]
- Feature: SharePoint Storage Creation \[[#64176](https://community.openproject.org/wp/64176)\]
- Feature: SharePoint Storage Basic Functionality \[[#64177](https://community.openproject.org/wp/64177)\]
- Feature: Comment fields for project attributes \[[#64264](https://community.openproject.org/wp/64264)\]
- Feature: Include storage configuration in health check download \[[#64477](https://community.openproject.org/wp/64477)\]
- Feature: Replace existing Project deletion confirmation page with Danger Dialog \[[#64885](https://community.openproject.org/wp/64885)\]
- Feature: Add deleted status to user. \[[#65068](https://community.openproject.org/wp/65068)\]
- Feature: FITKO styling &quot;Föderales IT- Standardisierungsboard&quot; of PDF export of meeting minutes \[[#65124](https://community.openproject.org/wp/65124)\]
- Feature: Redesign the &quot;My Account / Settings&quot; page using Primer \[[#65403](https://community.openproject.org/wp/65403)\]
- Feature: Improve budget handling in project queries and budget planning \[[#65783](https://community.openproject.org/wp/65783)\]
- Feature: Mobile App: Show projects, programs and portfolios \[[#65834](https://community.openproject.org/wp/65834)\]
- Feature: Show project attributes in sections in the mobile app \[[#65848](https://community.openproject.org/wp/65848)\]
- Feature: Add Risks, KPIs and Milestones to PDF export of project list \[[#65900](https://community.openproject.org/wp/65900)\]
- Feature: PDF export of project list \[[#65994](https://community.openproject.org/wp/65994)\]
- Feature: Create &#39;Email Updates Mode Selector&#39; component and use it in the Meetings and File storages modules \[[#66058](https://community.openproject.org/wp/66058)\]
- Feature: UI improvements for exisiting project &quot;Overview&quot; page \[[#66121](https://community.openproject.org/wp/66121)\]
- Feature: Send out email updates for meeting location changes \[[#66304](https://community.openproject.org/wp/66304)\]
- Feature: Collaborative editing \[[#66328](https://community.openproject.org/wp/66328)\]
- Feature: Swap position of search and create button in main navigation on mobile \[[#66339](https://community.openproject.org/wp/66339)\]
- Feature: Comment fields for project attributes \[[#66343](https://community.openproject.org/wp/66343)\]
- Feature: Custom font for all PDF Exports \[[#66384](https://community.openproject.org/wp/66384)\]
- Feature: Support Dark High Contrast color mode \[[#66395](https://community.openproject.org/wp/66395)\]
- Feature: Automatically sync the color mode with the OS preference \[[#66397](https://community.openproject.org/wp/66397)\]
- Feature: Project overview: Add a &#39;+ Widget&#39; primary button to subheader \[[#66426](https://community.openproject.org/wp/66426)\]
- Feature: Allow filtering and sorting for calculated values in the project list \[[#66431](https://community.openproject.org/wp/66431)\]
- Feature: /ServiceProviderConfig endpoint responds with limited output without authorization. \[[#66434](https://community.openproject.org/wp/66434)\]
- Feature: Automatically sync the contrast mode with the OS preference \[[#66460](https://community.openproject.org/wp/66460)\]
- Feature: Show project attributes in sections in the mobile app \[[#66641](https://community.openproject.org/wp/66641)\]
- Feature: Responds with 403 and proper message when enterprise plan is not enough. \[[#66706](https://community.openproject.org/wp/66706)\]
- Feature: Use ChronicDuration for meeting time input \[[#66712](https://community.openproject.org/wp/66712)\]
- Feature: Rename Nextcloud GroupFolder references to TeamFolder \[[#66722](https://community.openproject.org/wp/66722)\]
- Feature: Allow multi-select for managing participants \[[#66735](https://community.openproject.org/wp/66735)\]
- Feature: Show different placeholder texts for project select list \[[#66747](https://community.openproject.org/wp/66747)\]
- Feature: Update text related to meeting states (after updates to the participant dialog) \[[#66750](https://community.openproject.org/wp/66750)\]
- Feature: Provide &quot;open&quot;, &quot;closed&quot;, and &quot;locked&quot; operators to version work package filter \[[#66928](https://community.openproject.org/wp/66928)\]
- Feature: Primerise Account Settings (Language and Time Zone) pages \[[#66949](https://community.openproject.org/wp/66949)\]
- Bugfix: No date formatting in XLS export of Cost Report \[[#42761](https://community.openproject.org/wp/42761)\]
- Bugfix: API documentation on &quot;self link&quot; confusing \[[#43878](https://community.openproject.org/wp/43878)\]
- Bugfix: Useless Activity menu item in top menu \[[#59817](https://community.openproject.org/wp/59817)\]
- Bugfix: Some common duration formatting are not interpreted accurately \[[#60334](https://community.openproject.org/wp/60334)\]
- Bugfix: API: project/{id}/work\_packages?select=total fails when there are no work packages \[[#60672](https://community.openproject.org/wp/60672)\]
- Bugfix: Work package exports also show subprojects despite being excluded \[[#61940](https://community.openproject.org/wp/61940)\]
- Bugfix: No hierarchy in hierarchy field during bulk edit \[[#61970](https://community.openproject.org/wp/61970)\]
- Bugfix: Logging time form wrongfully suggests being able to log time for a group \[[#63517](https://community.openproject.org/wp/63517)\]
- Bugfix: Project identifier cannot be updated if a required project attribute is created \[[#63668](https://community.openproject.org/wp/63668)\]
- Bugfix: Manage outcomes permission lacks dependency to view meetings permission \[[#64018](https://community.openproject.org/wp/64018)\]
- Bugfix: CKEditor auto-save history (local) transfers between different text fields \[[#64252](https://community.openproject.org/wp/64252)\]
- Bugfix: Reminders: When an in-line validation error is displayed and the user corrects it by entering the missing information, dismiss the error \[[#64654](https://community.openproject.org/wp/64654)\]
- Bugfix: Status tag is positioned too close to the title in pdf report with long words in title \[[#64697](https://community.openproject.org/wp/64697)\]
- Bugfix: Possible to deactivate the default work package priority \[[#64842](https://community.openproject.org/wp/64842)\]
- Bugfix: Truncation of &quot;Tage&quot; (Days) in duration field when language=DE \[[#65227](https://community.openproject.org/wp/65227)\]
- Bugfix: Can&#39;t access attachments after classic meetings are getting converted to dynamic meetings \[[#65269](https://community.openproject.org/wp/65269)\]
- Bugfix: &quot;My spent time&quot; widget unexpectedly caching entries \[[#65509](https://community.openproject.org/wp/65509)\]
- Bugfix: TypeError in goodjob worker \[[#65557](https://community.openproject.org/wp/65557)\]
- Bugfix: Wrong selected menu, when moving from my page to a WP page \[[#65616](https://community.openproject.org/wp/65616)\]
- Bugfix: CFs that were added to an auto subject and are now inactive do not show the CF name \[[#65632](https://community.openproject.org/wp/65632)\]
- Bugfix: Second line of breadcrumb is not properly left-aligned on non-mobile/desktop viewports \[[#65635](https://community.openproject.org/wp/65635)\]
- Bugfix: Poor performance on a number of API endpoints (i.e. slow work package table) \[[#65718](https://community.openproject.org/wp/65718)\]
- Bugfix: Microsoft Entra user can not be found during sign in after being provisioned by SCIM client. \[[#65739](https://community.openproject.org/wp/65739)\]
- Bugfix: Error when exporting wp table grouped by project phase \[[#65740](https://community.openproject.org/wp/65740)\]
- Bugfix: Missing UI for oauth\_allow\_remapping\_of\_existing\_users setting \[[#65908](https://community.openproject.org/wp/65908)\]
- Bugfix: openproject run bundle exec rake redmine:email:receive\_imap delivers warnings to email every 5 minutes \[[#65993](https://community.openproject.org/wp/65993)\]
- Bugfix: WP menu sticks to the top of the browser window if WP type list is long \[[#66092](https://community.openproject.org/wp/66092)\]
- Bugfix: Validation of essential OIDC claims causes server error when failing \[[#66289](https://community.openproject.org/wp/66289)\]
- Bugfix: Side menu &#39;My time tracking&#39; doesn&#39;t take user to current day \[[#66425](https://community.openproject.org/wp/66425)\]
- Bugfix: ProtoPlugin not working with OpenProject 16 \[[#66430](https://community.openproject.org/wp/66430)\]
- Bugfix: A broken page in tree view look book page \[[#66441](https://community.openproject.org/wp/66441)\]
- Bugfix: Enable calculation of admin only calculated values on change of non admin only field values by non admins \[[#66471](https://community.openproject.org/wp/66471)\]
- Bugfix: It is not possible to submit calculated value field form by pressing Enter/Return inside formula \[[#66472](https://community.openproject.org/wp/66472)\]
- Bugfix: User cannot end a meeting series that has open occurrences \[[#66483](https://community.openproject.org/wp/66483)\]
- Bugfix: One time meeting organiser doesn&#39;t receive the meeting invite \[[#66497](https://community.openproject.org/wp/66497)\]
- Bugfix: WP number is visually truncated on time log entries table \[[#66504](https://community.openproject.org/wp/66504)\]
- Bugfix: File links from other project folders are not copied when user copies a project \[[#66513](https://community.openproject.org/wp/66513)\]
- Bugfix: API: Server error when passing invalid links \[[#66528](https://community.openproject.org/wp/66528)\]
- Bugfix: Update from OpenProject 13 to newer versions causes DB inconsistencies, Web freezes \[[#66552](https://community.openproject.org/wp/66552)\]
- Bugfix: API: timeEntries Link is not working \[[#66553](https://community.openproject.org/wp/66553)\]
- Bugfix: Sharepoint Storage Edit mentions Nextcloud Oauth \[[#66554](https://community.openproject.org/wp/66554)\]
- Bugfix: Sharepoint  Health Host check is missing translation key \[[#66556](https://community.openproject.org/wp/66556)\]
- Bugfix: LDAP-Group-Sync: groups are not sorted in drop down \[[#66582](https://community.openproject.org/wp/66582)\]
- Bugfix: Updating caret position on inserting pattern attribute fails with error \[[#66599](https://community.openproject.org/wp/66599)\]
- Bugfix: Projects list with URL project attribute cannot be exported \[[#66613](https://community.openproject.org/wp/66613)\]
- Bugfix: Trailing Slash on Storage Host leads to 500 \[[#66615](https://community.openproject.org/wp/66615)\]
- Bugfix: \[Accessibility\] Contrast issues in widget graphs \[[#66624](https://community.openproject.org/wp/66624)\]
- Bugfix: Last changes in formula when submitting by pressing Enter/Return inside formula are not saved \[[#66688](https://community.openproject.org/wp/66688)\]
- Bugfix: Admin only static and non affected calculated values are missing from calculations \[[#66738](https://community.openproject.org/wp/66738)\]
- Bugfix: time\_entries endpoint no longer supports work\_package filter \[[#66917](https://community.openproject.org/wp/66917)\]
- Bugfix: Update item error is not handled correctly \[[#66939](https://community.openproject.org/wp/66939)\]
- Bugfix: Updating Language in User Account Settings does not update the user&#39;s language on many pages \[[#66951](https://community.openproject.org/wp/66951)\]

<!-- END AUTOMATED SECTION -->
<!-- Warning: Anything above this line will be automatically removed by the release script -->

## Contributions
A very special thank you goes to our sponsors for this release.
Also a big thanks to our Community members for reporting bugs and helping us identify and provide fixes.
Special thanks for reporting and finding bugs go to Björn Schümann, Harald Herz, James Neale, Rince wind, Alexander Aleschenko, Sam Yelman, Stefan Weiberg, Tom Gugel, Johannes Baumgarten, Christoph Nodes, Not GivenByUser.

Last but not least, we are very grateful for our very engaged translation contributors on Crowdin, who translated quite a few OpenProject strings!
Would you like to help out with translations yourself?
Then take a look at our translation guide and find out exactly how you can contribute.
It is very much appreciated!


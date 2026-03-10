---
title: OpenProject 17.2.0
sidebar_navigation:
    title: 17.2.0
release_version: 17.2.0
release_date: 2026-03-11
---

 # OpenProject 17.2.0

 Release date: 2026-03-11

 We released OpenProject [OpenProject 17.2.0](https://community.openproject.org/versions/2246).
 The release contains several bug fixes and we recommend updating to the newest version.
 In these Release Notes, we will give an overview of important feature changes. At the end, you will find a complete list of all changes and bug fixes.

<!-- BEGIN CVE AUTOMATED SECTION -->

<!-- END CVE AUTOMATED SECTION -->

## Important feature changes

Take a look at our release video showing the most important features introduced in OpenProject 17.2.0:

![Release video of OpenProject 17.2]( UPDATE LINK) 

### MCP Server (Enterprise add-on)

[feature: mcp_server ]

OpenProject 17.2 introduces the **MCP Server**, a new Enterprise add-on that lays the foundation for robust integrations between OpenProject and AI systems, including large language models (LLMs), as well as other tools that use the Model Context Protocol (MCP). This server exposes OpenProject's APIv3 resources as MCP-compatible endpoints and enables secure, authenticated access for clients such as LLMs or other MCP clients, opening the door to richer contextual interactions with your project data.

Included in this release are administrative UI support for configuring the MCP Server, infrastructure and metadata endpoints, and integration of MCP authentication with OpenProject’s OAuth2 and API key mechanisms, including external OpenID Connect providers. An initial set of MCP tools and resources is provided to surface key entities (projects, work packages, users, etc.), and response formats can be adjusted based on your preferences. With session-cookie and bearer-token support, the MCP Server acts as a secure bridge between your OpenProject instance and external systems that operate via MCP. 

![Model context protocol settings in OpenProject administration](openproject_system_guide_new_mcp.png)

See the [**MCP Server documentation**](../../system-admin-guide/integrations/mcp-server/) for setup and examples.  

### Reusable meeting templates (Enterprise add-on)

[feature: meeting_templates ]

Preparing meetings often involves recreating the same agenda structure again and again. With OpenProject 17.2, administrators can now define reusable meeting templates that provide a predefined agenda layout for their teams.

These templates make it easy to start meetings with a proven structure instead of building the agenda from scratch each time. Even when meetings are not held regularly, teams can reuse well-designed formats that guide discussions and help ensure that important topics are addressed.

When creating a new one-time meeting, users can choose from the available templates to automatically populate the agenda with the predefined sections and items. This saves time during setup and promotes alignment across teams. 

![Meetings templates listed in an OpenProject project](openproject_release_notes_17-2-0_meetings_template.png)

For more details, please refer to the [Meetings documentation](../../user-guide/meetings/one-time-meetings/).

###  Allow requiring to be logged in to open external links (Enterprise add-on)

[feature: capture_external_links ]

Building on the external link safety options introduced in OpenProject 17.1, we’re expanding the protection capabilities in 17.2 to give administrators stronger safeguards for user interactions with links that lead outside of OpenProject.

Administrators can now require users to be logged in before following external links. When this setting is enabled, anyone who is not authenticated will be redirected to the login page before being allowed to continue to the external destination. 

![A setting to require users to be logged in before following an external link from OpenProject](openproject_release_notes_17-2-0_external_links_log_in.png)

Read more about [capturing external links in OpenProject](../../system-admin-guide/system-settings/external-links/).

### Project Overview page improvements

OpenProject 17.2 enhances the Project Overview to provide clearer financial insights, easier inline editing, and improved accessibility. Together, these updates make the Overview page a more powerful and inclusive central hub for project information.

#### Updated Overview widgets for Budgets

Project, program, and portfolio managers can now see key financial indicators at a glance. New budget widgets display planned budget, actual costs, spent ratio, and remaining budget, along with visual breakdowns by cost type and recent monthly actuals. Data is automatically aggregated across subprojects where applicable, giving stakeholders a consolidated financial snapshot without leaving the Overview page.

These widgets help teams better understand financial status and trends directly within their project context. Keep in mind that both the Budgets and Time & Costs modules need to be enabled for the widgets to work. 

![An example of project budget widget on a project home page in OpenProject](openproject_release_notes_17-2-0_budget_widget.png)

Read more about [budget widgets](../../user-guide/project-home/project-widgets/#budget-widget).

#### Editable project description and project status widgets on a Project view tab

The project description and project status widgets on the Overview tab are now editable inline. Based on your feedback, we’ve streamlined the experience so authorized users can update content directly where they view it, without switching to another tab.

Note that users without edit permissions will continue to see the content in read-only mode.

![Overview tab of a project home page in OpenProject, showing the project description widget being edited](openproject_system_guide_project_home_overview_tab_edit.png)

#### Improves accessibility of Project Overview and Dashboard Widgets

We have significantly improved the accessibility of widgets on both the Project Overview and Project dashboard pages. Widgets are now fully operable via keyboard, provide clearer structural semantics for screen readers, and follow WCAG 2.1 AA guidelines for focus management, labeling, and navigation order.

These improvements ensure that project information and controls are accessible to all users, including those relying on assistive technologies.

### Comment fields for project attributes 

OpenProject 17.2 introduces optional comment fields for project attributes, giving portfolio and project managers additional context behind selected values. Administrators can now enable a dedicated comment field for individual project attributes. This allows users to document the reasoning, assumptions, or background information related to a specific attribute value directly where it is maintained.

Comments are displayed and edited alongside the respective attribute on the Project overview page and follow the same permission logic as the attribute itself. Changes are tracked in the project activity, included in exports, and available via the API. By adding structured context to project metadata, this enhancement improves transparency and supports better governance and decision-making across projects and teams.

![Setting to add a comment text field to a project atttribute in OpenProject administration](openproject_release_notes_17-2-0_project_attributes_comment.png)

Read more about [project attributes in OpenProject](../../user-guide/project-home/project-attributes/).

### PDF export improvements

OpenProject 17.2 enhances PDF exports to provide more exhaustive and reliable reporting.

Work package queries can now include relationship columns in PDF reports. Related work packages are exported as structured tables within the document, making it easier to document complex relationships and dependencies in a clear and shareable format. This ensures that important contextual information is no longer lost when generating formal reports.

In addition, PDF exports now support WebP images embedded in work package descriptions. Images in this modern format are automatically included in the generated document, improving consistency between on-screen content and exported reports.

![Example of a PDF export in OpenProject, showing a work package that includes children and a webp image](openproject_system_guide_pdf_export.png)

Read more about [PDF exports in OpenProject](../../user-guide/work-packages/exporting/#pdf-export).

### UX/UI updates with the Primer design system

OpenProject 17.2 continues the transition to the Primer design system, further unifying the look and feel across the application.

#### Backlogs module update

The Backlogs module has been updated using Primer components. This resulted in a cleaner layout and more consistent interaction patterns, while still preserving familiar functionality such as drag-and-drop and version-based organization. Work packages can now be viewed in a split screen for improved context and efficiency.

![New UX/UI updates for the OpenProject Backlogs module](openproject_system_guide_new_backlog.png)

Read more about [Backlogs](../../user-guide/backlogs-scrum/).


#### Improvements in administration interface

Administrative interfaces for Custom Fields, Versions, and Groups have been further aligned with Primer. 

In particular, custom field forms are now consistently styled across all field types. Previously, the appearance varied depending on the type of custom field. This has been unified to provide a clearer and more predictable configuration experience for administrators.

###  Jira importer (feature flag)

We are working on a new Jira import wizard designed to help teams migrate core project data from Jira into OpenProject more easily. The importer focuses on bringing over essential user-generated content such as issues, comments, attachments, and project structures, reducing the need for manual recreation or fragile third-party workarounds. 

> [!IMPORTANT]
> This functionality is still under active development and currently available only behind a feature flag for early testing. We’re sharing this preview to start the conversation with teams considering a move from Jira. More capabilities will follow in upcoming releases.

![Add a new confgiruration to Jira importer under OpenProject administration](openproject_release_notes_17-2-0_jira_migrator.png)

To find out more [see what we are working on](https://community.openproject.org/projects/jira-migration/work_packages).

## Important updates and breaking changes

**“Enable REST web service” renamed**
The system setting previously labeled “Enable REST web service” is now called “Enable API tokens”. This is a naming change only and does not affect functionality.

**“Status” boards renamed to “Kanban” boards**
To better reflect their purpose and common terminology, Status boards are now called Kanban boards. Existing boards and configurations remain unchanged.

**Improved OAuth token security for document collaboration**
OAuth tokens used for collaborative document editing (BlockNote ↔ Hocuspocus) now have shorter lifetimes and are automatically refreshed. This enhances security while keeping the editing experience unchanged.
**API tokens usable as Bearer token**
Newly generated API tokens can directly be used as Bearer tokens and do not need to be presented as basic auth credentials with the username `apikey`. This is intended to make usage of our APIs easier. The previously existing basic auth flow is still supported.

<!--more-->

## Bug fixes and changes

<!-- Warning: Anything within the below lines will be automatically removed by the release script -->
<!-- BEGIN AUTOMATED SECTION -->

- Feature: Reusable meeting templates for meeting agendas [[#35642](https://community.openproject.org/wp/35642)]
- Feature: Primerized Backlogs list [[#57688](https://community.openproject.org/wp/57688)]
- Feature: Export relationship columns in PDF report [[#66000](https://community.openproject.org/wp/66000)]
- Feature: Overview widget for Budgets [[#66124](https://community.openproject.org/wp/66124)]
- Feature: Comment fields for project attributes [[#66343](https://community.openproject.org/wp/66343)]
- Feature: Make project description and status widget editable on Overview tab [[#67690](https://community.openproject.org/wp/67690)]
- Feature: Implement token refreshing and reduce token expiration time [[#68460](https://community.openproject.org/wp/68460)]
- Feature: Display custom field type on form [[#68524](https://community.openproject.org/wp/68524)]
- Feature: MCP Server Infrastructure and Metadata Endpoint [[#68683](https://community.openproject.org/wp/68683)]
- Feature: Integrate MCP Authentication with OpenProject OAuth2 [[#68685](https://community.openproject.org/wp/68685)]
- Feature: Provide initial set of MCP Tools [[#68686](https://community.openproject.org/wp/68686)]
- Feature: Expose OpenProject APIv3 Entities as MCP Resources [[#68689](https://community.openproject.org/wp/68689)]
- Feature: Add Admin Page for MCP Configuration [[#68690](https://community.openproject.org/wp/68690)]
- Feature: Standardized inplace edit fields based on Primer [[#68832](https://community.openproject.org/wp/68832)]
- Feature: Add enterprise banner for MCP server [[#70086](https://community.openproject.org/wp/70086)]
- Feature: Primerize Custom Field forms [[#70292](https://community.openproject.org/wp/70292)]
- Feature: Support WebP images in PDF exports [[#70333](https://community.openproject.org/wp/70333)]
- Feature: Rename status boards to kanban boards [[#70911](https://community.openproject.org/wp/70911)]
- Feature: Use autocompleters in Admin/Backlogs page [[#71069](https://community.openproject.org/wp/71069)]
- Feature: Improve Accessibility of Project Overview and Dashboard Widgets [[#71075](https://community.openproject.org/wp/71075)]
- Feature: Allow to use API Keys as Bearer tokens [[#71147](https://community.openproject.org/wp/71147)]
- Feature: Allow requiring to be logged in for external links [[#71624](https://community.openproject.org/wp/71624)]
- Feature: Primerize versions project settings [[#71641](https://community.openproject.org/wp/71641)]
- Feature: Primerize groups administration [[#71642](https://community.openproject.org/wp/71642)]
- Feature: Rename "Enable REST web service" setting [[#71886](https://community.openproject.org/wp/71886)]
- Feature: Reduce page size of MCP responses [[#71977](https://community.openproject.org/wp/71977)]
- Feature: Allow to configure MCP tool response volume [[#71978](https://community.openproject.org/wp/71978)]
- Feature: Allow authentication to MCP endpoint via session cookie [[#72253](https://community.openproject.org/wp/72253)]
- Feature: Enable Column Sorting on Versions Overview [[#72354](https://community.openproject.org/wp/72354)]
- Feature: Add "beta" label in MCP Admin settings headline [[#72511](https://community.openproject.org/wp/72511)]
- Feature: MCP Server as a bridge between OpenProject and LLMs [[#62781](https://community.openproject.org/wp/62781)]
- Bugfix: Children column on WP list cannot be expanded [[#64491](https://community.openproject.org/wp/64491)]
- Bugfix: DPA/AVV cannot be downloaded [[#67323](https://community.openproject.org/wp/67323)]
- Bugfix: BlockNote: Color for text not applied from the block side menu [[#67507](https://community.openproject.org/wp/67507)]
- Bugfix: Mobile web: When deep linking to a comment the comment is not fully scrolled into view [[#68221](https://community.openproject.org/wp/68221)]
- Bugfix: Updating the activity anchor URL without a page load does not highlight the relevant target element [[#68262](https://community.openproject.org/wp/68262)]
- Bugfix: Documents index page: pagination per page options overflow on mobile [[#68533](https://community.openproject.org/wp/68533)]
- Bugfix: Changing the filter on the activity tab with a large number of comments and slow network/compute lacks loading state while waiting for request completion [[#68878](https://community.openproject.org/wp/68878)]
- Bugfix: Flickering spec ./modules/meeting/spec/features/structured_meetings/work_package_meetings_tab_spec.rb:392 [[#68952](https://community.openproject.org/wp/68952)]
- Bugfix: Clicking work package tabs triggers page reload and flickering [[#69210](https://community.openproject.org/wp/69210)]
- Bugfix: Label for the admin document types reflects "priorities" instead of "types" in its messaging [[#69304](https://community.openproject.org/wp/69304)]
- Bugfix: Infinite SAML Seeding Loop Causing Disk Space Exhaustion [[#69339](https://community.openproject.org/wp/69339)]
- Bugfix: "Show attachments in the files tab by default" potentially overwrites the setting for existing project [[#69991](https://community.openproject.org/wp/69991)]
- Bugfix: Fix accessibility errors found by ERB Lint [[#70166](https://community.openproject.org/wp/70166)]
- Bugfix: Missing list items when using checkboxes in tables [[#70537](https://community.openproject.org/wp/70537)]
- Bugfix: Documents: when document content exceeds vertical height, the cursor does not scroll into view unless there is content typed [[#70791](https://community.openproject.org/wp/70791)]
- Bugfix: Helm-Chart: Allow user to provide service specific annotations [[#71055](https://community.openproject.org/wp/71055)]
- Bugfix: Activity tab overflows with long names [[#71106](https://community.openproject.org/wp/71106)]
- Bugfix: Multi-user custom field requires clicking twice in order to be in focus [[#71135](https://community.openproject.org/wp/71135)]
- Bugfix: Status translation issue on status widget [[#71137](https://community.openproject.org/wp/71137)]
- Bugfix: Unnecessary empty journals on dragging work packages with automatic subjects [[#71421](https://community.openproject.org/wp/71421)]
- Bugfix: Sending mails via sendmail does not work [[#71447](https://community.openproject.org/wp/71447)]
- Bugfix: Error Content-Security-Policy with Hocuspocus integration due to URL scheme misconfiguration [[#71888](https://community.openproject.org/wp/71888)]
- Bugfix: BlockNote Extension: Click on WP title opens new tab and redirects the current tab [[#71898](https://community.openproject.org/wp/71898)]
- Bugfix: Connection error on successive navigation to and from a document [[#71901](https://community.openproject.org/wp/71901)]
- Bugfix: Impossible to search for archived projects, page reverts to active projects list on its own [[#71971](https://community.openproject.org/wp/71971)]
- Bugfix: Remove presenter field/participants references in onetime templates [[#72222](https://community.openproject.org/wp/72222)]
- Bugfix: Space is too small for placeholder text in Backlogs module [[#72366](https://community.openproject.org/wp/72366)]
- Bugfix: Missing caption in new template dialog [[#72375](https://community.openproject.org/wp/72375)]
- Bugfix: Wrong wording in Enterprise on-prem support token input field [[#72459](https://community.openproject.org/wp/72459)]


<!-- END AUTOMATED SECTION -->
<!-- Warning: Anything above this line will be automatically removed by the release script -->

## Contributions
A very special thank you goes to AMG, Helmholtz-Zentrum Berlin, City of Cologne, Deutsche Bahn and ZenDiS for sponsoring released or upcoming features. Your support, alongside the efforts of our amazing Community, helps drive these innovations.

Also a big thanks to our Community members for reporting bugs and helping us identify and provide fixes. Special thanks for reporting and finding bugs go to Alexander Aleschenko, Gabor Alexovics, Jörg Mollowitz and Александр Татаринцев. 

Last but not least, we are very grateful for our very engaged translation contributors on Crowdin, who translated quite a few OpenProject strings! This release we would like to particularly thank the following users:

- [Adam Siemienski](https://crowdin.com/profile/siemienas), for a great number of translations into Polish.
- [Mehmet Coşkun](https://crowdin.com/profile/mmehmet.ccoskun), for a great number of translations into Turkish.
- [Liangzdz](https://crowdin.com/profile/liangzdz), for a great number of translations into Chinese Simplified.

Would you like to help out with translations yourself? Then take a look at our [translation guide](../../contributions-guide/translate-openproject/) and find out exactly how you can contribute. It is very much appreciated!
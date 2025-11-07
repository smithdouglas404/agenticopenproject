---
sidebar_navigation:
  title: JIRA migration
  priority: 90
---

# Migrating from Jira and Confluence to OpenProject

> [!NOTE]
>
> This page is a work in progress. The OpenProject team is actively developing an upcoming Jira and Confluence migration tool. Information on this page may change as new migration options become available.
>
> Last edition date: UPDATE WHEN PUBLISHING

## Overview

This guide provides an overview of the current options for migrating data from Atlassian Jira or Confluence to OpenProject. It also describes ongoing community and in-house development efforts for dedicated migration solutions.

With the [end of life for Jira Data Center](https://www.openproject.org/blog/jira-alternative-end-of-data-center/), many organizations are evaluating OpenProject as a secure, open-source, and self-hosted alternative for project management and collaboration.

## Migration Options

### 1. OpenProject migration tool

OpenProject is developing a solution for migrating from Jira and Confluence. You can follow progress of OpenProject's [JIRA migration Stream](https://community.openproject.org/projects/jira-migration)  and provide your feedback. This tool will simplify data import for Jira projects, including:

- Issue types
- Fields and custom fields
- Attachments
- Workflows

> [!NOTE]
> This feature is under active development and not yet available for production use.

**Contributing and data donation**

To support the development of the official migration tool, we are collecting anonymized data samples. This data helps test and validate import capabilities across different Jira and Confluence configurations.

> [!TIP]
> Please reach out to us if you want to donate your data, we will sign an NDA to ensure confidentiality.

### 2. API

Use the [OpenProject REST API](https://www.openproject.org/docs/api) to migrate data programmatically. This option provides full flexibility and supports most OpenProject entities, such as:

- Work packages
- Users
- Comments
- Attachments

> [! NOTE]
> The API-based approach requires technical expertise and scripting or integration development to map Jira and Confluence data structures to OpenProject.



### 3. Excel synchronization

The [Excel synchronization integration](https://www.openproject.org/docs/system-admin-guide/integrations/excel-synchronization) allows you to import and export tabular data between Jira, Confluence, and OpenProject using spreadsheets.
 This method is suitable for small to medium-sized migrations and provides an opportunity to review and clean data manually before import.

### 4. Confluence → Markdown → Wiki

You can migrate Confluence content into OpenProject using Markdown export and manual import:

1. Use a Markdown export app such as [Markdown Exporter for Confluence](https://marketplace.atlassian.com/apps/1221351/markdown-exporter-for-confluence) 
2. Copy and paste the exported Markdown into the OpenProject Wiki module.
3. Verify formatting and structure after import.
4. Upload attachments manually (these are not included in the Markdown export).

This approach preserves most layout elements and is recommended for documentation or knowledge base content.

### 5. Community-developed Jira importer

A community-developed tool, the [OpenProject Jira Importer](https://github.com/dotnetfactory/openproject-jira-importer) provides additional import capabilities.
 It supports importing Jira issues into OpenProject and is available as open-source software.

Refer to the [Jira migration community development blog article](https://www.openproject.org/blog/jira-migration-community-development/) for background information and usage guidance.

### 6. Partner support

Our [partners at ALMToolbox](https://www.almtoolbox.com/) offer professional migration assistance for Jira and Confluence.  They can support complex migration projects and ensure data integrity during the transition.

## Recommended migration workflow

1. **Preparation**
   - Document your existing Jira and Confluence configuration (projects, issue types, workflows, fields, spaces).
   - Identify which data to migrate and which to archive.
   - Clean up legacy data before starting.
2. **Testing**
   - Set up a test instance of OpenProject.
   - Migrate a small subset of data using one of the methods described above.
   - Verify field mappings, attachments, and relationships.
3. **Execution**
   - Perform the full migration after successful testing.
   - Validate data integrity after import.
   - Recreate workflows, permissions, and boards in OpenProject as required.
4. **Post-migration**
   - Provide training to users.
   - Archive or decommission the legacy systems if applicable.


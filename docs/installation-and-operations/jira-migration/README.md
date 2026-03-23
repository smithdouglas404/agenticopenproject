---
sidebar_navigation:
  title: JIRA migration
  priority: 90
---

# Migrating from JIRA to OpenProject

Last edited on: March 22, 2026.

The OpenProject team is actively developing an import tool for Jira Data Center. This feature is under active development. We release new features with every release. Information on this page may change as new migration options become available.

## Purpose of the migration wizard

With the [end of life for JIRA Data Center](https://www.openproject.org/blog/jira-alternative-end-of-data-center/), many organizations are evaluating [OpenProject as a secure, open-source, and self-hosted alternative for project management and collaboration](https://www.openproject.org/alternative-atlassian-jira-data-center/).

> [!WARNING]
>
> This feature is under active development. Please only use it in test setups. We inform you about our progress and our recommendations when you can use it in production setups.

## Data covered by the import wizard

This import tool is currently in beta and can only import basic data: 

- Projects
- Issues (name, title, description, attachments)
- Users (name, email, project membership)
- Statuses
- Types

## Data not covered by the import yet

- Workflows
- Custom fields
- Issue relations
- Permissions.

## Supported Jira versions

- We currently  only support Jira Server/Data Center versions 10.x and 11.x.
- Cloud  instances are **not** supported at this time.

## Import preparation

### Enable the feature flag

Navigate to *admin/settings/experimental* and enable the setting *Jira import*.

### Setup the API connection

Navigate to *Administration → Import*. To create a new import configuration, click the **+ Jira configuration** button.

![Jira importer settings under OpenProject administration](openproject_admin_import_jira_import.png)

Provide the following details:
-  A name for the import configuration
-  Your Jira Server or Data Center URL
-  A Personal Access Token. The migration tool requires a token with admin permissions. Otherwise you will get 403 error during the import process.

### Test configuration

Click **Test configuration** to verify the connection.

![Define new Jira import in OpenProject adminstration](openproject_admin_import_jira_import_new_config.png)
If the connection is successful, a confirmation banner will appear.

![Successful connection message for Jira import](openproject_admin_import_jira_import_new_config_test.png)

Click **Add configuration** to proceed to the import runs overview. Initially, no import runs will be listed.

## Import run

You can import different sets of data with each import run. It is  possible to undo an import run immediately after in review mode but not  after finalizing.

![Empty import runs overview after creating a Jira import configuration](openproject_admin_import_jira_import_new_config_import_run_button.png)

Click **Import run** to start a new import.

### Check available data

In the *Get base data* section, click **Check available data** to retrieve metadata from your Jira instance.

![Checking available Jira data for import](openproject_admin_import_jira_import_check_data.png)

Once fetched, you will see which data can and cannot be imported. Click **Continue**.

### Configure import



![Overview of available and unavailable Jira data for import](openproject_admin_import_jira_import_data_fetched.png)

### Select projects

Next, select the projects you want to import. Click **Select projects**.

![Select projects button in Jira import configuration](openproject_admin_import_jira_import_data_fetched_select_project_button.png)

In the modal dialog, choose one or more projects and confirm by clicking **Continue**.

![Project selection modal showing available Jira projects](openproject_admin_import_jira_import_select_projects_modal.png)

### Start import

Click **Start import** to begin the import process.

![Start import button in Jira import workflow](openproject_admin_import_jira_import_start_import_button.png)

A warning dialog will appear. Confirm that you understand the limitations (e.g., incomplete feature coverage, recommendation to avoid production use, and the need for backups). Select *I understand* and click **Start import**.

![Warning dialog before starting Jira import](openproject_admin_import_jira_import_warning_banner.png)

During import, Jira wiki markup is automatically converted to OpenProject’s markdown format.

> [!TIP]
> If a user already exists in OpenProject from a previous import, they will not be duplicated.

### Review import

After the import completes, the data is available in *review mode*. You can:

-  Inspect imported projects and work packages
-  Validate data integrity
-  Decide whether to finalize or revert the import

![Example of an imported work package in review mode](openproject_admin_import_jira_import_imported_work_package_example.png)

### Finalize or revert the import

To proceed, choose one of the following actions: finalize or revert the import.

![Finalize or revert import buttons in review mode](openproject_admin_import_jira_import_finalize_or_revert_import_buttons.png)

#### Finalize import

- Activates newly created users
- Makes imported data permanent
- Disables the option to revert the import

A confirmation warning will be shown before proceeding.

![Confirmation dialog for finalizing import](openproject_admin_import_jira_import_proceed_import_warning_banner.png)

#### Revert import

- Removes all data created during the current import run
- Does not affect data from previous import runs

A confirmation warning will also be shown.

![Confirmation dialog for reverting import](openproject_admin_import_jira_import_revert_import_warning_banner.png)

> [!NOTE]
> During review mode, any newly created users remain locked until the import is finalized.

## Best practices for Jira migrations

### 1. Preparation

- Document your existing JIRA and Confluence configuration (projects, issue types, workflows, fields, spaces).
- Identify which data to migrate and which to archive.
- Clean up legacy data before starting.

### 2. Testing

- Set up a test instance of OpenProject.
- Migrate a small subset of data using one of the methods described above.
- Verify field mappings, attachments, and relationships.

### 3. Execution

- Perform the full migration after successful testing.
- Validate data integrity after import.
- Recreate workflows, permissions, and boards in OpenProject as required.

### 4. Post-migration

- Provide training to users.
- Archive or decommission the legacy systems if applicable.

## Current status and next steps of the import wizard

You can follow the progress of OpenProject's [JIRA migration Stream](https://community.openproject.org/projects/jira-migration) and provide feedback.

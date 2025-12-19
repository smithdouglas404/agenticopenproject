---
sidebar_navigation:
  title: Create work packages
  priority: 990
description: How to create Work packages in OpenProject.
keywords: create work package, new work package, add work package
---

# Create Work packages

| Topic                                                                  | Content                                        |
|------------------------------------------------------------------------|------------------------------------------------|
| [Create Work packages](#create-work-packages)                          | How to create a new Work package in a project. |
| [Add attachments to a Work package](#add-attachments-to-work-packages) | How to add attachments to a Work package.      |

## Create Work packages

There are several ways to create work packages in OpenProject:

- [Through the header navigation](#create-a-work-package-via-header-navigation). 
- [In-line in the Work package table](#create-a-work-package-in-the-table-view) to quickly create multiple Work packages.
- [In a split screen](#create-a-work-package-in-the-split-screen-view) which allows you to specify detailed information from the start.

### Create a Work package via header navigation

You can create a work package from anywhere within application by clicking the green **+** button in the header navigation and directly selecting a work package type.

![Button to create work packages from the header navigation of OpenProject ](openproject_user_guide_work_package_create_new_wp_button_header_navigation.png)

### Create a Work package in work packages module

You can also create work package directly from within the work package module (either within a specific project, or from the global module level). 

[Select a project](../../../getting-started/projects/#open-an-existing-project) and navigate to the Work package module in the project module menu on the left. Alternatively select the work packages global module.

![Work packages module highlighted in the project menu in OpenProject](openproject_user_guide_work_package_module.png)

Click the **+ Create** button above the the work packages table and select the type of work package you want to create. 

![Button to create a new work package above the work packages table view in OpenProject](openproject_user_guide_work_package_create_new_wp_button_wp_table.png)


### Create a Work package in the table view

To create new Work packages directly in line in the table view, click on the **+ Create new Work package** link below the table.

![Link at the bottom of the work packages table to creat a new work package directly in the table view in OpenProject](openproject_user_guide_work_package_create_new_link.png)

The new Work package appears in a highlighted row in the table. Type in the subject of the Work package, change attributes, such as Type or Status directly in the table and hit Enter to save the changes.

![Form to create a new work package directly in a work package table in OpenProject](openproject_user_guide_work_package_create_new_wp_inline_form.png)

This way, you can quickly and easily create new Work packages in the table, just like in Excel.

### Create a Work package in the split screen view

In order to enter detailed information to the Work package from the start, you can create a Work package in the split screen view. In the Work package module, click the green **+ Create** button and select the type of Work package you want to create.

![Select work package type](1566303633018.png)

The new Work package form will open in the split screen view. Enter all information, such as description, assignee, status, priority, due date and more.

Click the green **Save** button.

![create a work package in the split screen view](1566303947314.png)

Starting with OpenProject 13.0 you can add emojis to all text editors, including the work package description. Type a colon and a letter, e.g. **:a** into the text editor and get a suggested list of emojis you can use.

![work package description emojis](openproject_user_guide_wp_description_emojis.png)

To find out **how to create a child Work package** please click [here](../work-package-relations-hierarchies/#add-a-child-work-package).

## Add attachments to Work packages

You can directly add images, e.g. via copy and paste to the **Work package description**. You can also use the toolbar above the Work package description and click the Insert image icon:

![insert-image](1566304978459.png)

Also, at the bottom of the Work package form you can add files via drag and drop or select the file from a folder to upload it to the Work package.

![add-file](1566305040178.png)

> [!NOTE]
> It is also possible for users that are not members of the project to add attachments to work packages if they have been granted the permission by an administrator. This can be useful for example for confirming bug reports.

Find out how to [edit existing Work packages](../edit-work-package).

> [!NOTE]
> you can also use [Nextcloud integration](../../file-management/nextcloud-integration/#link-files-and-folders-to-work-packages) to upload files to Nextcloud or link already existing files or folders to a work package under the tab **Files**.

---
sidebar_navigation:
  title: MCP Server
  priority: 500
description: Integrate AI agents with your OpenProject instance through MCP.
keywords: ai llm mcp
---
# MCP Server

> [!IMPORTANT]
> MCP server is an experimental feature that's not yet intended for production usage. It must be enabled on the page for experimental
> features of your OpenProject instance (found under `/admin/settings/experimental`). Future versions might change this feature in a breaking
> way, as we still look for user feedback on this feature.

[feature: mcp_server ]

OpenProject allows AI agents and similar tools to integrate through an API called **Model Context Protocol** (MCP).
This allows these agents to access information from your OpenProject instance into their responses. Right now OpenProject only offers
read-only tools, tools to manipulate data might be added in the future.

## Configuring authentication

Authentication with MCP can happen in the ways that authentication for regular API endpoints can happen as well. The two distinct
use cases for authentication are authentication for a single user via personal API tokens or authentication for different users
sharing the same (web) application through OAuth.

### Personal access with API tokens

This way of authentication requires no further setup on the administration side of OpenProject.
The only requirement is that the ["Enable REST web service"](../../api-and-webhooks/) setting is enabled.

Afterwards users that want to make use of MCP on a personal basis, can create a personal API token and configure an MCP client with that
token. However, this only works properly with locally running MCP clients that are only used by a single user and it requires the user
to configure the MCP endpoint themselves.

### Shared access via OAuth

If multiple users shall be able to use information from the same OpenProject instance and when using web-based MCP clients, the typical
configuration will involve an admin setting up the MCP client and OpenProject once, so that regular users can then utilize the
preconfigured connection, granting the MCP client the necessary permissions through an OAuth flow.

The MCP endpoints require access with a token that includes the `mcp` scope. These tokens can be obtained in all ways usually supported
by OpenProject already, namely:

* [Tokens issued from OpenProject](../../authentication/oauth-applications/)
* Tokens issued from a compliant OpenID Connect provider

In case OpenProject is used as the authentication provider, the configuration for the client has to be prepared by the administrator.
Go to _Administration -> Authentication -> OAuth applications_ and create an application with the `mcp` scope, entering
the "Redirect URI" according to the instructions of your MCP client. Make sure that the application is marked as confidential.

## Customization

TODO: What can be customized in the Admin UI

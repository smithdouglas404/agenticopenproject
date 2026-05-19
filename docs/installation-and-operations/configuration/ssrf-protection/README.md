---
sidebar_navigation:
  title: SSRF protection
---

# SSRF protection

## What is SSRF?

Server-Side Request Forgery (SSRF) is an attack where an attacker tricks the server into making HTTP requests to
unintended destinations - typically internal network resources that are not reachable from the public internet.

For example, if OpenProject can be configured to connect to an external URL (such as a Jira instance, a webhook
endpoint, or an outbound email server), an attacker could supply an internal IP address like `127.0.0.1` or
`192.168.1.10` or `169.254.169.254` (the AWS EC2 instance metadata endpoint) instead of a legitimate hostname.
The server would then fetch that internal resource on the attacker's behalf, potentially exposing internal services,
cloud credentials, or other sensitive data.

OpenProject blocks outbound connections to private and link-local IP ranges by default to prevent this class of attack.

## When does SSRF protection block connections?

Any feature that causes OpenProject to initiate an outbound HTTP connection is subject to SSRF protection. This
includes:

- Jira Migrator connections to a Jira Data Center instance
- Webhook deliveries
- Outgoing email server tests
- Any other integration that requires a URL to be configured by an administrator

If the target host resolves to a private IP address - even if you entered a hostname rather than a raw IP - the
connection will be blocked.

## Allowing non-public IP addresses

When your Jira instance (or other integration target) runs on an internal network, you must explicitly allow its IP
address or subnet using the `OPENPROJECT_SSRF__PROTECTION__IP__ALLOWLIST` environment variable.

The variable accepts a comma- or space-separated list of IPv4 and IPv6 addresses, including CIDR range notation.

**Examples:**

Allow a single host:

```
OPENPROJECT_SSRF__PROTECTION__IP__ALLOWLIST=192.168.1.42
```

Allow an entire subnet:

```
OPENPROJECT_SSRF__PROTECTION__IP__ALLOWLIST=192.168.0.0/16
```

Allow multiple ranges:

```
OPENPROJECT_SSRF__PROTECTION__IP__ALLOWLIST=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

> [!WARNING]
> Only add IP addresses or ranges that you control and trust. Overly broad allowlists reduce the effectiveness of SSRF
> protection.

## Why an environment variable and not a UI setting?

Allowing internal IP ranges is a server-level security decision, not an application-level one.

Environment variables can only be changed by whoever controls the server or deployment
configuration - typically a system administrator or infrastructure team. A UI setting can be changed by any OpenProject
administrator with access to the web interface, which would render this protection ineffective. 

These are two different trust levels, and a security control that limits the attack surface of the server should 
require the higher level of access to modify.

## Setting the environment variable

Please see the [environment variables reference](../environment/) about environment variables.

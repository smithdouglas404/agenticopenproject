# Setup guide

A minimal setup guide for using a local XWiki inside a docker stack. The example compose file is connected to the
standard setup of the TLS-ready stack with `traefik`.

## First steps

- Up the docker stack with `docker compose --project-directory docker/dev/xwiki/ up -d`
- Go to https://xwiki.local
- Wait for initialisation to succeed
- Create admin user
- Select XWiki standard flavor and install it — **this is highly recommended** as many XWiki
  features and the OpenProject plugin depend on it

## Recommended extensions

For integration with OpenProject, install the following after the standard flavor is set up:

- **[OpenProject Integration](https://store.xwiki.com/xwiki/bin/view/Extension/OpenProjectIntegration)** — connects XWiki with OpenProject

Install it via the Extension Manager (Administration → Extensions → search for "OpenProject Integration").

## Updating XWiki

To update XWiki to a newer version, pull the latest image and recreate the container:

```bash
docker compose --project-directory docker/dev/xwiki/ pull
docker compose --project-directory docker/dev/xwiki/ up -d
```

After the container starts, go to <https://xwiki.local> — XWiki will detect the new version and
present an upgrade wizard. Follow it to completion before using XWiki again.

## Certificates

### Trusting the local CA in your browser

If your browser shows a certificate warning for `https://xwiki.local`, import the step-ca root
certificate into your browser. This is the same CA used by the rest of the TLS stack, so if
OpenProject or Nextcloud already work without warnings, no action is needed.

### Trusting the local CA in XWiki (for outbound HTTPS calls)

XWiki runs on Java/Tomcat which has its own certificate truststore, independent of the system CA
bundle. If XWiki needs to make HTTPS requests to OpenProject (e.g. for OAuth), it must trust the
local step-ca root certificate.

Copy `docker-compose.override.example.yml` to `docker-compose.override.yml` — it wraps the XWiki
entrypoint to automatically import the step-ca certificate into Java's truststore on every container
start, including after recreations. Requires the TLS stack (`docker/dev/tls`) to be running.

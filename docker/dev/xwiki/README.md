# Setup guide

A minimal setup guide for using a local XWiki inside a docker stack. The example compose file is connected to the
standard setup of the TLS-ready stack with `traefik`.

## First steps

- Up the docker stack with `docker compose --project-directory docker/dev/xwiki/ up -d`
- Go to https://xwiki.local
- Wait for initialisation to succeed
- Create admin user
- Select XWiki standard flavor and install it

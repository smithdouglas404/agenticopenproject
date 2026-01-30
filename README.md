# op-blocknote-hocuspocus

[![Tests](https://github.com/opf/op-blocknote-hocuspocus/actions/workflows/test.yml/badge.svg)](https://github.com/opf/op-blocknote-hocuspocus/actions/workflows/test.yml)
[![Docker](https://github.com/opf/op-blocknote-hocuspocus/actions/workflows/docker.yml/badge.svg)](https://github.com/opf/op-blocknote-hocuspocus/actions/workflows/docker.yml)

A real-time collaborative editing server for [OpenProject](https://www.openproject.org/) documents, powered by [Yjs](https://github.com/yjs/yjs) and [Hocuspocus](https://tiptap.dev/docs/hocuspocus/introduction).

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/opf/op-blocknote-hocuspocus.git
cd op-blocknote-hocuspocus

# Install dependencies
npm install

# Start the server with the appropriate environment variables setup
SECRET=secret12345 npm run start
```

The `SECRET` environment variable is a shared value between this application and OpenProject. Make sure to configure the same value in OpenProject - Settings Hocuspocus secret and in the `SECRET` environment variable of this project.

### Using Docker

```bash
docker pull openproject/hocuspocus:latest

docker run -d \
  -p 1234:1234 \
  -e SECRET=secret12345 \
  openproject/hocuspocus:latest
```

## Configuration & Usage

### Configuration

#### `OPENPROJECT_URL` (default `undefined`)

This is the base URL hocuspocus will use to connect to OpenProject.
It is undefined by default, in which case the URL is derived from the edited resources (e.g. documents) in OpenProject.

This can fail in some cases where hocuspocus cannot reach the host under the given URL,
for instance when using the docker compose setup with `localhost` for the OpenProject host.
In this case hocuspocus would try to connect to itself.

To fix that you can configure `OPENPROJECT_URL` to 'rebase' the resource URLs to the given value.

For instance, in the case of docker compose:

```bash
OPENPROJECT_URL=http://web
```

Where `web` is the DNS name for the OpenProject container in the docker compose setup.

> When overriding the base URL like this, you also need to set `OPENPROJECT_HOST` (see below) to make requests work.

#### `OPENPROJECT_HOST` (default `undefined`)

When connecting to OpenProject using a different URL than the one OpenProject is configured to be accessd from publicly,
you also need to make sure to override the `Host` header used in requests made to OpenProject by hocuspocus.

Looking at the example above, accessing OpenProject under `http://web` will not work, because OpenProject will return
an `Invalid host_name configuration` error.
Overriding the `Host` header with OpenProject's public host addresses this error.

```bash
OPENPROJECT_HOST=localhost
```

### Starting the Server

```bash
# Development Mode (with hot reload):
npm run dev

# Production Mode
npm run start

# Debug Mode (with Node.js inspector):
npm run debug

# Run tests
npm run test

# Lint code
npm run lint
```

## Links

- [OpenProject](https://www.openproject.org/)
- [Hocuspocus Documentation](https://tiptap.dev/docs/hocuspocus/introduction)
- [Yjs Documentation](https://docs.yjs.dev/)
- [BlockNote Editor](https://www.blocknotejs.org/)
- [Repository Issues](https://github.com/opf/op-blocknote-hocuspocus/issues)

---

**Maintained by the OpenProject team**

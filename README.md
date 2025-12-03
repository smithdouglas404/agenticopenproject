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
ALLOWED_DOMAINS=your-openproject-domain.com SECRET=secret12345 npm run start
```

For the server to be able to reach to an OpenProject instance, it is necessary to set the environment variable `ALLOWED_DOMAINS`. It is a comma-separated list of domains (and it allows subdomain matching).

```
ALLOWED_DOMAINS=subdomain-openproject.example.com,top-level-openproject.com`
```

The `SECRET` environment variable is a shared value between this application and OpenProject. Make sure to configure the same value in OpenProject - Settings Hocuspocus secret and in the `SECRET` environment variable of this project.

### Using Docker

```bash
docker pull openproject/hocuspocus:latest

docker run -d \
  -p 1234:1234 \
  -e ALLOWED_DOMAINS=your-openproject-domain.com \
  -e SECRET=secret12345 \
  openproject/hocuspocus:latest
```

## Usage

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

# Deploy OpenProject on Ubuntu 22.04 (No Docker)

This guide installs OpenProject using the official Debian packages on Ubuntu 22.04 (Jammy), without containers.

## 1. Requirements

- OS: Ubuntu Server 22.04 (x86_64).
- Hardware (minimum): 4 vCPU / 4 GB RAM / 20 GB disk (≈200 users). Increase for larger loads.
- Network: Outbound HTTPS to download packages, inbound HTTP/HTTPS for users.
- Database: PostgreSQL 16+ (17 recommended). PostgreSQL 17 is required for newer major versions; see `./installation-and-operations/misc/migration-to-postgresql17/` for migration details. UTF8 encoding required.
- SSL: Optional but recommended (Let's Encrypt supported by installer).

## 2. Prepare the system

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates wget
```

## 3. Add OpenProject APT repository (stable 17)

```bash
# Import signing key
sudo curl -fsSL https://packages.openproject.com/srv/deb/opf/openproject/gpg-key.gpg \
  -o /usr/share/keyrings/openproject.gpg

# Add repo list for Ubuntu 22.04
sudo curl -fsSL \
  https://packages.openproject.com/srv/opf/openproject/stable/17/installer/ubuntu/22.04.list \
  -o /etc/apt/sources.list.d/openproject.list

sudo apt-get update
```

## 4. Install OpenProject package

```bash
sudo apt-get install -y openproject
```

This creates the `openproject` system user, systemd services, and layout under `/var/lib/openproject`.

## 5. Run configuration wizard

```bash
sudo openproject reconfigure   # interactive (recommended)
# sudo openproject configure   # non-interactive if config already saved
```

Wizard choices:

- Edition (Standard/BIM).
- Database: create local PostgreSQL or connect to external. For external, prepare `HOST/PORT/DB/USER/PASS`.
- Web server & SSL: auto-configure Apache2 and optional Let's Encrypt; or skip if using your own proxy.
- Cache: memcached.
- Hostname / protocol.
- Admin email & SMTP settings.

## 6. External PostgreSQL reference

If you use an external DB, create it first:

```sql
CREATE DATABASE openproject ENCODING 'UTF8' LC_COLLATE 'C' LC_CTYPE 'C';
CREATE USER op_user WITH PASSWORD 'STRONG_PASSWORD';
ALTER DATABASE openproject OWNER TO op_user;
```

Connection URL example:

```
postgresql://op_user:STRONG_PASSWORD@db.example.com:5432/openproject
```

OpenProject requires UTF8 encoding; the `C` locale satisfies this requirement. Incompatible encodings will abort during boot.

## 7. Services

- Web/API: systemd service `openproject`.
- Background jobs: managed by the same package (GoodJob/PostgreSQL).
- Logs: `journalctl -u openproject`.
- Assets/uploads: `/var/lib/openproject` (persist and back up).

## 8. Upgrades

```bash
sudo apt-get update
sudo apt-get install openproject
sudo openproject configure
```

If upgrading across major versions, ensure the repo URL matches the target major (e.g., `stable/17`).

## 9. Backup essentials

- Database: `pg_dump` or `pg_basebackup`.
- File data: `/var/lib/openproject` (attachments, repos).
- Keep copies before major upgrades.

## 10. Troubleshooting quick checks

- Service status: `systemctl status openproject`
- Recent logs: `journalctl -u openproject -n 200`
- DB connectivity: `psql <DATABASE_URL>`
- Encoding/ICU errors: re-create DB with UTF8 + ICU-compatible locale.

## 11. Useful links

- Installation & operations guide: `./installation-and-operations/`
- System requirements: `./installation-and-operations/system-requirements/`
- PostgreSQL 17 migration notice: `./installation-and-operations/misc/migration-to-postgresql17/`

---

## 12. Local development on WSL (Ubuntu) — PostgreSQL already installed

This section covers running OpenProject in **development mode** inside WSL 2 (Ubuntu 22.04) when PostgreSQL is already available on the host/WSL instance.

> **Note**: This is a development setup only, not suitable for production.
> Recommended hardware: 4 vCPU / 8 GB RAM (16 GB preferred).

### 12.1 Install system dependencies

```bash
sudo apt-get update
sudo apt-get install -y git curl build-essential zlib1g-dev libyaml-dev \
  libssl-dev libpq-dev libreadline-dev
```

### 12.2 Install Ruby 3.4.7 via rbenv

```bash
# Install rbenv
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
source ~/.bashrc

# Install ruby-build plugin
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# Install Ruby (match version in .ruby-version)
rbenv install 3.4.7
rbenv global 3.4.7
rbenv rehash
```

### 12.3 Install Node.js 22 via nodenv

```bash
# Install nodenv
git clone https://github.com/nodenv/nodenv.git ~/.nodenv
echo 'export PATH="$HOME/.nodenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(nodenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install node-build plugin
git clone https://github.com/nodenv/node-build.git $(nodenv root)/plugins/node-build

# Install Node.js (match version required by the project)
nodenv install 22.21.0
nodenv global 22.21.0
nodenv rehash

# Update npm
npm install npm@latest -g
```

### 12.4 Prepare PostgreSQL databases

Assuming PostgreSQL is already running. Create the dev and test databases:

```bash
sudo -u postgres psql <<'SQL'
CREATE USER openproject WITH PASSWORD 'openproject-dev-password' CREATEDB;
CREATE DATABASE openproject_dev  ENCODING 'UTF8' OWNER openproject;
CREATE DATABASE openproject_test ENCODING 'UTF8' OWNER openproject;
SQL
```

> If your PostgreSQL runs on a custom port or socket path, adjust `host` / `port` in `config/database.yml` below.

### 12.5 Clone the repository and configure

```bash
mkdir -p ~/dev && cd ~/dev
git clone https://github.com/LaveyD/openproject.git
cd openproject
```

Create `config/database.yml`:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  host: localhost
  username: openproject
  password: openproject-dev-password

development:
  <<: *default
  database: openproject_dev

test:
  <<: *default
  database: openproject_test
```

Copy and optionally edit the environment file:

```bash
cp .env.example .env
```

### 12.6 Install dependencies and seed the database

```bash
# Installs gems, node modules, links plugin modules, exports locale files
bin/setup_dev

# Seed the development database
RAILS_ENV=development bin/rails db:seed
```

### 12.7 Start the application

The easiest way is via `bin/dev` (uses **overmind** or **foreman** if available):

```bash
# Install overmind (recommended process manager)
# Download the binary for Linux from https://github.com/DarthSim/overmind/releases
# e.g.:
curl -Lo /usr/local/bin/overmind.gz \
  https://github.com/DarthSim/overmind/releases/latest/download/overmind-v2.5.1-linux-amd64.gz
gunzip /usr/local/bin/overmind.gz && chmod +x /usr/local/bin/overmind

# Then start all processes
bin/dev
```

Alternatively, start processes individually in separate terminals:

```bash
# Terminal 1 — Rails web server
RAILS_ENV=development bin/rails server

# Terminal 2 — Frontend (Angular dev server with hot reload)
RAILS_ENV=development npm run serve

# Terminal 3 — Background job worker
RAILS_ENV=development bundle exec good_job start
```

### 12.8 Access the application

| URL | Description |
|-----|-------------|
| `http://localhost:3000` | Rails server (full app) |
| `http://localhost:4200` | Frontend dev server (hot reload) |

Default admin credentials: **Username** `admin` / **Password** `admin`.

### 12.9 Common WSL tips

- **PostgreSQL not starting**: In WSL 2, systemd may not be enabled. Start PostgreSQL manually: `sudo service postgresql start`.
- **Port already in use**: Check with `ss -tlnp | grep 3000` and kill the conflicting process.
- **Slow file watching**: Add the repository to WSL file system (`~/`) rather than the mounted Windows drive (`/mnt/c/`) for much better performance.
- **Log file**: `log/development.log` in the project root.

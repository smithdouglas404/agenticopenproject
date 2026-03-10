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

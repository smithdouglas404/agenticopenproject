---
sidebar_navigation:
  title: Attachment export (S3-compatible)
  priority: 10
description: Incrementally back up all OpenProject attachments using any S3-compatible client.
keywords: backup, attachments, S3, aws s3 sync, rclone, export
---

# Attachment export via S3-compatible endpoint

OpenProject exposes a **read-only, S3-compatible endpoint** that lets administrators incrementally download all attachments using standard tooling such as the AWS CLI or rclone.

Unlike the built-in backup feature, which creates a full tar archive on every run, the S3 endpoint returns checksums (ETags) for each file. Sync tools use these to skip files that have not changed, making repeated runs fast and bandwidth-efficient.

## Requirements

- OpenProject administrator account with backups enabled
- A **backup token** (the same token used for the built-in backup feature)
- AWS CLI v2 **or** rclone (or any other S3-compatible client)

## Authentication and audit trail

This endpoint uses your **backup token** as the AWS access key ID. This is intentional: every backup token reset sends a notification to the token owner and all administrators, creating the same audit trail as the existing backup feature. Treat the backup token with the same care as any backup credential.

You can find and manage your backup token at **Administration → Backup**.

> **Note:** The backup token has a 24-hour waiting period after creation before it can be used. This is a safety measure inherited from the backup system.

## Endpoint

```
https://<your-openproject-host>/s3/openproject
```

The bucket name is always `openproject`. Object keys use the format `{attachment_id}/{filename}`, for example `4217/design-mockup.png`.

## Syncing with the AWS CLI

Supply your backup token as the **AWS access key ID**. The secret access key value is not verified — any non-empty string works.

```bash
aws s3 sync \
  s3://openproject/ \
  ./openproject-attachments/ \
  --endpoint-url https://<your-openproject-host>/s3 \
  --no-sign-request \
  --request-checksum-calculation when_required
```

> **`--no-sign-request` note:** Some AWS CLI versions (≥ 2.22) require this flag when using a custom endpoint that does not verify Signature V4. If your version rejects it, omit the flag and pass credentials via environment variables instead (see below).

### Passing credentials via environment variables

```bash
export AWS_ACCESS_KEY_ID=<your-backup-token>
export AWS_SECRET_ACCESS_KEY=unused

aws s3 sync \
  s3://openproject/ \
  ./openproject-attachments/ \
  --endpoint-url https://<your-openproject-host>/s3
```

### Passing credentials via a named profile

Add to `~/.aws/credentials`:

```ini
[openproject-backup]
aws_access_key_id     = <your-backup-token>
aws_secret_access_key = unused
```

Then run:

```bash
aws s3 sync \
  s3://openproject/ \
  ./openproject-attachments/ \
  --endpoint-url https://<your-openproject-host>/s3 \
  --profile openproject-backup
```

## Syncing with rclone

Add a remote to your rclone configuration (`rclone config`):

```ini
[op-attachments]
type                 = s3
provider             = Other
endpoint             = https://<your-openproject-host>/s3
access_key_id        = <your-backup-token>
secret_access_key    = unused
no_check_bucket      = true
```

Then sync:

```bash
rclone sync op-attachments:openproject ./openproject-attachments/
```

Rclone compares ETags before downloading, so only new or changed files are transferred.

## How incremental sync works

Every attachment record in OpenProject stores an MD5 checksum (`digest`). The S3 endpoint returns this as the object's ETag. When you run a sync:

1. The client fetches the full object listing (paginated in batches of 1 000).
2. For each object, the local ETag is compared to the remote ETag.
3. Only objects with a mismatched or missing ETag are downloaded.

This means the first run downloads everything; subsequent runs only transfer new or modified attachments, regardless of total attachment size.

## Object key format

Keys are stable identifiers in the form `{attachment_id}/{original_filename}`, for example:

```
4217/design-mockup.png
4218/budget-q3.xlsx
```

The numeric prefix is the attachment's database ID, which never changes even if the file is moved between work packages. Restoring from a backup therefore does not require parsing any directory structure — every file can be re-imported independently.

## Limitations

- **Administrator only.** The endpoint is restricted to administrators holding a valid backup token. Per-user or per-project scoped access is planned for a future release.
- **Read-only.** Only `ListObjectsV2`, `GetObject`, and `HeadObject` are implemented. Uploads and deletes are not supported.
- **No prefix filtering.** The `?prefix=` parameter is accepted but not applied server-side. Use `--exclude` / `--include` patterns in your S3 client instead.
- **Attachments in progress are excluded.** Files still being uploaded (`prepared` status) and files flagged by antivirus scanning (`quarantined` status) do not appear in the listing.
- **Requires backups to be enabled.** If `OPENPROJECT_BACKUP_ENABLED` is set to `false` in your configuration, this endpoint returns `403 AccessDenied`.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `403 AccessDenied` | The backup token is invalid, belongs to a non-admin user, or backups are disabled in configuration. |
| `403 AccessDenied` with cooldown message | The backup token was recently created and is still in the 24-hour waiting period. |
| `401 InvalidAccessKeyId` | No `Authorization` header was sent, or the credential field is empty. |
| `404 NoSuchBucket` | The bucket name in the URL is not `openproject`. |
| Empty listing | No attachments have a stored digest yet. This can happen if all attachments were uploaded before digest computation was introduced. |

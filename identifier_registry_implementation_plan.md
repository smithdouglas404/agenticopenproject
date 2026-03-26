# Identifier Registry: Implementation Plan

## Overview

Add support for semantic work package identifiers (e.g. `PROJ-123`) alongside existing global numeric IDs (`#45678`). The numeric ID remains the primary key forever — semantic identifiers are aliases.

The chosen approach is the **Identifier Registry**: a dedicated `work_package_semantic_ids` table that acts as an append-only registry of all identifier→WP mappings, past and present. No timestamps, no expiry, no FriendlyId dependency for WP resolution.

---

## New Database Structure

### `work_package_semantic_ids`

```ruby
create_table :work_package_semantic_ids do |t|
  t.string :identifier, null: false
  t.references :work_package, null: false, foreign_key: true
  t.boolean :current, null: false, default: false
end

add_index :work_package_semantic_ids, :identifier, unique: true
add_index :work_package_semantic_ids, [:work_package_id, :current],
          where: "current = true",
          unique: true,
          name: :idx_wp_semantic_ids_current
```

- `identifier` — the full composite identifier string, e.g. `PROJ-123`
- `work_package_id` — always points to the current, live WP (never changes even after moves)
- `current` — true for the WP's active identifier, false for all historic ones
- Unique index on `identifier` — enforces no two WPs share an identifier, makes lookups O(log n)
- Partial unique index on `(work_package_id, current) WHERE current = true` — enforces only one current identifier per WP at any time
- No `valid_from` / `valid_until` — rows are never deleted or expired
- No `work_package_moves` table needed — registry re-pointing handles move history implicitly

### Changes to `work_packages`

```ruby
add_column :work_packages, :sequence_number, :integer
add_index :work_packages, [:project_id, :sequence_number], unique: true
```

No `identifier` column on `work_packages` — the registry is the single source of truth.

### Changes to `projects`

```ruby
add_column :projects, :wp_sequence_counter, :integer, default: 0, null: false
```

Atomic counter for sequence allocation. No advisory locks needed — `UPDATE projects SET wp_sequence_counter = wp_sequence_counter + 1 RETURNING wp_sequence_counter` is atomic at the DB level.

---

## Sequence Allocation

Use the counter column on `projects`. On WP creation:

```ruby
def allocate_sequence!(project)
  project.with_lock do
    project.increment!(:wp_sequence_counter)
    project.wp_sequence_counter
  end
end
```

- Atomic — no advisory locks needed
- Gap-free — counter only increments on successful commit
- Backfill: `UPDATE projects SET wp_sequence_counter = (SELECT MAX(sequence_number) FROM work_packages WHERE project_id = projects.id)`

---

## Write Operations

### WP Creation

1. Allocate sequence number via counter column
2. Set `work_packages.sequence_number = next_seq`
3. Insert into registry: `(identifier: "#{project.identifier}-#{next_seq}", work_package_id: wp.id, current: true)`

### WP Move (e.g. PROJ-5 moves to OTHER, becomes OTHER-42)

1. Allocate new sequence number in target project
2. Update `work_packages`: `sequence_number = 42, project_id = OTHER`
3. Set old registry row to `current: false`: `WHERE work_package_id = wp.id AND current = true`
4. Insert new registry row: `(identifier: "OTHER-42", work_package_id: wp.id, current: true)`

The old row `PROJ-5: WP123` remains with `current: false` — it still resolves correctly since `work_package_id` hasn't changed.

### Project Rename (e.g. PROJ → PROJ_NEW)

1. Update `projects.identifier`
2. Set all current rows for project WPs to `current: false`:
   ```sql
   UPDATE work_package_semantic_ids
   SET current = false
   WHERE current = true
   AND identifier LIKE 'PROJ-%'
   ```
3. Bulk insert new prefix rows for **all WPs ever associated with this project**:
   ```sql
   INSERT INTO work_package_semantic_ids (identifier, work_package_id, current)
   SELECT 'PROJ_NEW-' || w.sequence_number, s.work_package_id, true
   FROM work_package_semantic_ids s
   JOIN work_packages w ON w.id = s.work_package_id
   WHERE s.identifier LIKE 'PROJ-%'
   AND NOT EXISTS (
     SELECT 1 FROM work_package_semantic_ids
     WHERE identifier = 'PROJ_NEW-' || w.sequence_number
   )
   ```

- Queries the registry itself (not just current WPs) to catch WPs that previously lived in this project but have since moved
- NOT EXISTS guard makes it safe to retry and safe under concurrent WP creation
- Old prefix rows (`PROJ-*`) remain with `current: false` — they continue to resolve correctly

---

## Read / Resolution

### Lookup flow for any identifier param

```
Parse param
  |
  ├── numeric? → SELECT * FROM work_packages WHERE id = N
  |
  └── semantic (e.g. PROJ-123)?
        |
        ├── SELECT wp.* FROM work_packages wp
        │   JOIN work_package_semantic_ids s ON s.work_package_id = wp.id
        │   WHERE s.identifier = 'PROJ-123'
        │   → found? return WP
        |
        └── miss → compute fallback
              |
              ├── Parse prefix PROJ, sequence 123
              ├── Resolve project: SELECT * FROM projects WHERE identifier = 'PROJ'
              │   → miss? → SELECT via friendly_id_slugs (projects) WHERE slug = 'PROJ'
              ├── SELECT * FROM work_packages
              │   WHERE project_id = X AND sequence_number = 123
              → found? return WP
              → miss? → 404
```

The compute fallback handles:
- Ghost identifiers (new WPs looked up via old project prefix)
- Any registry miss due to edge cases

### Access control

Apply visibility scopes **after** resolving `work_package_id` from the registry — never expose the registry lookup result directly. The controller should scope through `WorkPackage.visible(user).find(wp_id)` after resolution.

---

## Model Associations

```ruby
class WorkPackage < ApplicationRecord
  has_many :semantic_ids,
           class_name: "WorkPackageSemanticId",
           foreign_key: :work_package_id,
           inverse_of: :work_package

  has_one :current_semantic_id,
          -> { where(current: true) },
          class_name: "WorkPackageSemanticId",
          foreign_key: :work_package_id

  has_many :other_semantic_ids,
           -> { where(current: false) },
           class_name: "WorkPackageSemanticId",
           foreign_key: :work_package_id
end
```

- `semantic_ids` — all registry entries for this WP, current and historic
- `current_semantic_id` — the single entry with `current: true`, enforced by partial unique index
- `other_semantic_ids` — all historic entries (old project names, previous identifiers after moves)

---

## Finder Implementation

A single entry point for all identifier types:

```ruby
module WorkPackages
  class IdentifierFinder
    def self.find(param, user: nil)
      return find_by_pk(param, user:) if param.to_s.match?(/\A\d+\z/)
      find_by_semantic(param, user:)
    end

    private

    def self.find_by_pk(id, user:)
      scope(user).find(id)
    end

    def self.find_by_semantic(identifier, user:)
      # 1. Registry lookup
      wp_id = WorkPackageSemanticId.find_by(identifier:)&.work_package_id
      return scope(user).find(wp_id) if wp_id

      # 2. Compute fallback
      prefix, seq = parse(identifier)
      return nil unless prefix && seq

      project = resolve_project(prefix)
      return nil unless project

      scope(user).find_by(project:, sequence_number: seq)
    end

    def self.parse(identifier)
      m = identifier.match(/\A([A-Za-z][A-Za-z0-9_]*)-(\d+)\z/)
      m ? [m[1], m[2].to_i] : nil
    end

    def self.resolve_project(prefix)
      Project.find_by(identifier: prefix) || Project.friendly.find(prefix)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def self.scope(user)
      user ? WorkPackage.visible(user) : WorkPackage.all
    end
  end
end
```

---

## Backfill Strategy

Triggered when switching from numeric to semantic mode. Idempotent — safe to re-run.

```ruby
# Per project, in batches
Project.find_each do |project|
  # 1. Set sequence counter to current MAX
  max = WorkPackage.where(project:).maximum(:sequence_number).to_i
  project.update_columns(wp_sequence_counter: max)

  # 2. Assign sequence numbers to unassigned WPs
  WorkPackage.where(project:, sequence_number: nil).order(:id).find_each.with_index(max + 1) do |wp, seq|
    wp.update_columns(sequence_number: seq)
    project.update_columns(wp_sequence_counter: seq)
  end

  # 3. Populate registry for all WPs in project
  WorkPackage.where(project:).find_each do |wp|
    WorkPackageSemanticId.find_or_create_by!(
      identifier: "#{project.identifier}-#{wp.sequence_number}",
      work_package_id: wp.id
    )
  end
end
```

---

## Routes & Controllers

- Loosen route constraint from `{ id: /\d+/ }` to `{ id: /[A-Za-z0-9_-]+/ }` where WP params are accepted
- Replace `WorkPackage.find(params[:id])` with `WorkPackages::IdentifierFinder.find(params[:id], user: current_user)` at controller entry points
- `find_by(id:)` and `exists?` with user-supplied params need updating — internal FK-based calls are unaffected
- Keep `_links.self.href` using numeric ID — external integrations depend on it
- Add `identifier` property to API v3 representer (additive, no breaking changes)

---

## Known Constraints & Decisions

- Project identifiers cannot be reused after renaming — enforced by existing uniqueness constraints
- WPs are never deleted, only closed — no orphaned registry rows
- Case sensitivity: identifiers are case-sensitive, consistent with existing project identifier behaviour
- Sequences are gap-free under normal operation (counter column, no NEXTVAL)
- Concurrent WP creation during rename: NOT EXISTS guard on bulk INSERT handles safely
- Access control leak: always apply visibility scope after registry lookup, never expose raw registry results
- `#1234` global numeric IDs continue working forever via PK fallback
- Cross-project text references (`PROJ-123` in WP descriptions) are out of scope for this iteration

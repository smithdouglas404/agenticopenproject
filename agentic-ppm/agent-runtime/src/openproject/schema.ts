/**
 * OpenProject work-package schema discovery.
 *
 * NEW BUILD. Pulls the live attribute set (standard fields + custom fields) from
 * OpenProject's APIv3 schema endpoint and normalizes each into an
 * AttributeDescriptor the mapping layer consumes. This is the SOURCE side of the
 * universal mapper: "what attributes does this OpenProject instance actually
 * have?" — discovered, never hand-listed, so customFieldN fields show up too.
 *
 * Tolerant of 403/404 (locked-down or older instances): falls back to the known
 * standard attribute set. Cached with a short TTL so the mapping UI is snappy.
 */
import { getOpenProjectClient } from './client.js';
import type { AttributeDescriptor, AttributeType } from '../mapping/types.js';

const SOURCE = 'openproject';

/**
 * OpenProject schema `type`/`_type` string -> our AttributeType.
 * The keys are the APIv3 attribute `type` values (e.g. "Integer", "Formattable",
 * "User", "Duration", "DateTime", "Boolean", and custom-field shapes).
 */
function mapOpType(opType: string | undefined, key: string): AttributeType {
  const t = (opType ?? '').toLowerCase();
  // Percentage fields are integers in OP but semantically a percentage.
  if (/percent|percentagedone/i.test(key)) return 'percentage';
  if (t.includes('duration')) return 'duration';
  if (t.includes('date')) return 'date'; // Date | DateTime
  if (t === 'boolean') return 'boolean';
  if (t === 'integer' || t === 'float') return 'number';
  if (t === 'user') return 'user';
  if (t === 'priority' || t === 'status' || t === 'type' || t === 'version' || t === 'category') {
    return 'enum';
  }
  // Custom-field list shapes ("[]CustomOption", "CustomOption").
  if (t.includes('customoption')) return t.startsWith('[]') ? 'list' : 'enum';
  if (t.startsWith('[]')) return 'list';
  if (t === 'formattable' || t === 'string' || t === 'text') return 'string';
  return 'string';
}

/** Pull the enum/list allowed values out of a schema attribute, when embedded. */
function enumValuesOf(attr: any): string[] | undefined {
  const embedded = attr?._embedded?.allowedValues;
  if (Array.isArray(embedded) && embedded.length > 0) {
    const vals = embedded
      .map((v: any) => v?.name ?? v?.value ?? v?.title)
      .filter((v: unknown): v is string => typeof v === 'string');
    return vals.length > 0 ? vals : undefined;
  }
  return undefined;
}

/** The standard OpenProject attributes always present — the offline/forbidden fallback. */
function standardAttributes(): AttributeDescriptor[] {
  const std: Array<[string, string, AttributeType]> = [
    ['subject', 'Subject', 'string'],
    ['description', 'Description', 'string'],
    ['status', 'Status', 'enum'],
    ['priority', 'Priority', 'enum'],
    ['type', 'Type', 'enum'],
    ['assignee', 'Assignee', 'user'],
    ['responsible', 'Accountable', 'user'],
    ['startDate', 'Start date', 'date'],
    ['dueDate', 'Finish date', 'date'],
    ['percentageDone', '% Complete', 'percentage'],
    ['estimatedTime', 'Estimated time', 'duration'],
    ['spentTime', 'Spent time', 'duration'],
    ['storyPoints', 'Story points', 'number'],
    ['version', 'Version', 'enum'],
    ['category', 'Category', 'enum'],
  ];
  return std.map(([key, label, type]) => ({ key, label, type, source: SOURCE, custom: false }));
}

const CACHE_TTL_MS = 60_000;
let cache: { at: number; value: AttributeDescriptor[] } | null = null;

/**
 * Discover every work-package attribute (standard + custom) on this OpenProject
 * instance. Merges the schema-collection attributes with the custom-field
 * definitions; de-dupes by key. Degrades to the standard set on any failure.
 */
export async function discoverSchema(opts?: { force?: boolean }): Promise<AttributeDescriptor[]> {
  if (!opts?.force && cache && Date.now() - cache.at < CACHE_TTL_MS) {
    return cache.value.map((d) => ({ ...d }));
  }

  const op = getOpenProjectClient();
  const byKey = new Map<string, AttributeDescriptor>();

  // Seed with the standard set so we always return something sensible.
  for (const d of standardAttributes()) byKey.set(d.key, d);

  try {
    const schemas = await op.getWorkPackageSchemas();
    for (const schema of schemas) {
      for (const [key, attr] of Object.entries(schema as Record<string, any>)) {
        // Skip the JSON-LD envelope + link/embedded scaffolding.
        if (key.startsWith('_') || typeof attr !== 'object' || attr === null) continue;
        if (typeof (attr as any).type !== 'string' && typeof (attr as any).name !== 'string') continue;

        const isCustom = /^customField\d+$/.test(key);
        const type = mapOpType((attr as any).type, key);
        const descriptor: AttributeDescriptor = {
          key,
          label: (attr as any).name ?? key,
          type,
          source: SOURCE,
          custom: isCustom,
        };
        const enumValues = enumValuesOf(attr);
        if (enumValues) descriptor.enumValues = enumValues;
        // Schemas describe the same standard attribute repeatedly; keep the
        // richest (one that brought enumValues) but don't let an empty later
        // schema clobber an earlier good one.
        const existing = byKey.get(key);
        if (!existing || (!existing.enumValues && enumValues)) byKey.set(key, descriptor);
      }
    }
  } catch {
    // Hard failure on the schemas endpoint — keep the standard set.
  }

  try {
    const customFields = await op.getCustomFields();
    for (const cf of customFields) {
      const id = cf?.id;
      if (id == null) continue;
      const key = `customField${id}`;
      const descriptor: AttributeDescriptor = {
        key,
        label: cf?.name ?? key,
        type: mapOpType(cf?.fieldFormat ?? cf?.type, key),
        source: SOURCE,
        custom: true,
      };
      const values = Array.isArray(cf?.possibleValues)
        ? cf.possibleValues.filter((v: unknown): v is string => typeof v === 'string')
        : undefined;
      if (values && values.length > 0) descriptor.enumValues = values;
      // A custom-field definition is authoritative for its own values.
      if (!byKey.has(key) || descriptor.enumValues) byKey.set(key, descriptor);
    }
  } catch {
    // custom_fields not exposed on this version — fine.
  }

  const result = [...byKey.values()];
  cache = { at: Date.now(), value: result };
  return result.map((d) => ({ ...d }));
}

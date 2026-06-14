/**
 * Mapping persistence + auto-match seeding.
 *
 * NEW BUILD. A SourceMappingSet is stored as ONE (:MappingSet {source, json})
 * node — the whole set serialized to a JSON string (FalkorDB holds scalars, not
 * nested objects). When nothing is saved yet, getMapping() returns a sensible
 * default: discoverSchema() crossed with the ontology properties, auto-matched
 * by name/type, with a default widget per attribute type pre-filled. Never
 * throws on an empty/unreachable graph — degrades to the in-memory default.
 */
import { getGraph } from '../graph/falkor.js';
import { discoverSchema } from '../openproject/schema.js';
import { listOntologyProperties } from './ontologyProperties.js';
import { defaultWidgetForType } from './widgets.js';
import type {
  AttributeDescriptor,
  AttributeMapping,
  OntologyProperty,
  SourceMappingSet,
} from './types.js';

const NODE_ID_PREFIX = 'mappingset-';

/** Normalize a label/key/id fragment for fuzzy name matching ("% Complete" -> "complete"). */
function norm(s: string): string {
  return s
    .toLowerCase()
    .replace(/^[a-z0-9]+:/, '') // drop a namespace prefix (pm:foo -> foo)
    .replace(/[^a-z0-9]+/g, ''); // strip spaces/punct
}

/** Pick a transform implied by an attribute/property pairing. */
function transformFor(
  attr: AttributeDescriptor,
  prop: OntologyProperty | undefined,
): AttributeMapping['transform'] {
  if (attr.type === 'duration') return 'iso_duration_hours';
  if (prop?.id === 'pm:status') return 'status_map';
  if (prop?.id === 'pm:priority') return 'priority_map';
  return 'none';
}

/**
 * Auto-match heuristic: for each discovered attribute, find the ontology
 * property whose name or type best fits, and pre-fill ontologyProperty + a
 * default widget. Exact-name match wins; otherwise a same-type fallback for the
 * common single-valued types. Unmatched attributes come back with an empty
 * ontologyProperty (the UI offers a dropdown).
 */
function autoMatch(
  attributes: AttributeDescriptor[],
  properties: OntologyProperty[],
): AttributeMapping[] {
  // Hand aliases for fields whose source name differs from the spine label.
  const ALIASES: Record<string, string> = {
    subject: 'pm:name',
    duedate: 'pm:dueDate',
    finishdate: 'pm:dueDate',
    percentagedone: 'pm:percentComplete',
    percentcomplete: 'pm:percentComplete',
    estimatedtime: 'pm:effortHours',
    spenttime: 'pm:actualHours',
    responsible: 'pm:assignee',
    accountable: 'pm:assignee',
    version: 'pm:release',
  };

  const byNormName = new Map<string, OntologyProperty>();
  for (const p of properties) {
    byNormName.set(norm(p.id), p);
    byNormName.set(norm(p.label), p);
  }

  return attributes.map((attr) => {
    const candidates = [norm(attr.key), norm(attr.label)];
    let prop: OntologyProperty | undefined;
    for (const c of candidates) {
      prop = byNormName.get(c);
      if (prop) break;
      const aliasId = ALIASES[c];
      if (aliasId) {
        prop = properties.find((p) => p.id === aliasId);
        if (prop) break;
      }
    }

    const mapping: AttributeMapping = {
      sourceKey: attr.key,
      sourceLabel: attr.label,
      ontologyProperty: prop?.id ?? '',
      transform: transformFor(attr, prop),
      synced: Boolean(prop), // sync matched attributes by default
    };
    const widget = defaultWidgetForType(attr.type);
    if (widget) mapping.widget = widget;
    return mapping;
  });
}

/** Build the default mapping set for a source from discovery + auto-match. */
async function defaultMappingSet(source: string): Promise<SourceMappingSet> {
  // Discovery is OpenProject-shaped today; other sources start empty until a
  // dedicated discoverer exists. Never throw — fall back to an empty set.
  let attributes: AttributeDescriptor[] = [];
  if (source === 'openproject') {
    attributes = await discoverSchema().catch(() => []);
  }
  const mappings = autoMatch(attributes, listOntologyProperties());
  return { source, mappings, updatedAt: new Date().toISOString() };
}

/**
 * Load the saved mapping set for a source, or a freshly seeded default when none
 * is persisted. Graph/discovery failures degrade to the default, never throw.
 */
export async function getMapping(source: string): Promise<SourceMappingSet> {
  try {
    const rows = await getGraph().query<{ json: string }>(
      `MATCH (m:MappingSet { id: $id }) RETURN m.json AS json`,
      { id: `${NODE_ID_PREFIX}${source}` },
    );
    const json = rows[0]?.json;
    if (typeof json === 'string' && json.length > 0) {
      const parsed = JSON.parse(json) as SourceMappingSet;
      if (parsed && Array.isArray(parsed.mappings)) return parsed;
    }
  } catch {
    // graph unreachable or bad JSON — fall through to the default.
  }
  return defaultMappingSet(source);
}

/** Persist a mapping set as a single (:MappingSet) node holding the JSON string. */
export async function saveMapping(set: SourceMappingSet): Promise<void> {
  const toSave: SourceMappingSet = {
    source: set.source,
    mappings: Array.isArray(set.mappings) ? set.mappings : [],
    updatedAt: new Date().toISOString(),
  };
  await getGraph().upsertNode({
    id: `${NODE_ID_PREFIX}${toSave.source}`,
    label: 'MappingSet',
    properties: {
      source: toSave.source,
      json: JSON.stringify(toSave),
      updatedAt: toSave.updatedAt,
    },
  });
}

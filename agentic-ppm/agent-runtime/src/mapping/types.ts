/**
 * Ontology-as-universal-mapper — the mapping model.
 *
 * NEW BUILD. The runtime is the GROUNDING layer (no LLM reasoning): these are
 * the deterministic shapes the Kyndral UI + agents consume to map any source's
 * native attributes onto the canonical spine (src/ontology/spine.ts) and to
 * pick a sensible widget per attribute type. Kept framework-neutral so adding
 * Jira/MSP/Planview later is config, not code.
 */

/** The universe of attribute types a source field can carry (superset of spine prop types). */
export type AttributeType =
  | 'string'
  | 'number'
  | 'percentage'
  | 'currency'
  | 'date'
  | 'boolean'
  | 'enum'
  | 'list'
  | 'user'
  | 'duration'
  | 'hierarchy'
  | 'relation';

/** A single discovered attribute on a source (standard field or custom field). */
export interface AttributeDescriptor {
  /** Source-native key, e.g. "subject", "percentageDone", "customField12". */
  key: string;
  /** Human label as the source presents it, e.g. "Subject", "% Complete". */
  label: string;
  type: AttributeType;
  /** Originating system, e.g. "openproject". */
  source: string;
  /** True for source custom fields (customFieldN), false/undefined for standard ones. */
  custom?: boolean;
  /** Allowed values for enum/list types, when the source advertises them. */
  enumValues?: string[];
}

/** A canonical property on the spine that a source field can map onto. */
export interface OntologyProperty {
  /** Namespaced id, e.g. "pm:percentComplete", "safe:riskScore". */
  id: string;
  label: string;
  type: AttributeType;
  description?: string;
}

/** A renderable widget, e.g. a KPI tile or a progress bar. */
export type WidgetType = string;

/** A widget the catalog offers, plus which attribute types it can render. */
export interface WidgetDescriptor {
  id: WidgetType;
  label: string;
  appliesTo: AttributeType[];
}

/** How one source attribute maps onto an ontology property (+ optional widget + transform). */
export interface AttributeMapping {
  /** Source-native key (matches AttributeDescriptor.key). */
  sourceKey: string;
  /** Source label captured at mapping time (for display without a re-discovery). */
  sourceLabel: string;
  /** Target ontology property id, e.g. "pm:percentComplete" (empty = unmapped). */
  ontologyProperty: string;
  /** Optional value transform applied on ingest. */
  transform?: 'status_map' | 'priority_map' | 'iso_duration_hours' | 'none';
  /** Chosen widget id (from the widget catalog) for this attribute. */
  widget?: string;
  /** Whether the runtime should write this attribute onto the graph node. */
  synced: boolean;
}

/** The full set of mappings for one source, persisted as a single graph node. */
export interface SourceMappingSet {
  /** Source system, e.g. "openproject". */
  source: string;
  mappings: AttributeMapping[];
  /** ISO timestamp of the last save. */
  updatedAt: string;
}

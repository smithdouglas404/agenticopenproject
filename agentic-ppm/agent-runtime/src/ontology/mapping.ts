/**
 * Ontology mapping layer — the executable form of bridging.ttl.
 *
 * Turns a (sourceSystem, nativeType, fields) triple into a canonical spine label
 * + dialect class, and normalizes native field names onto canonical properties.
 * This is shared by every adapter; adding Jira/MSP/Planview later is just adding
 * the config tables below.
 *
 * Data here mirrors bridging.ttl "External System Aliases" + "Reconciliation
 * Rules" so the ontology stays the source of truth and this stays generated-from.
 */
import type { SpineLabel, SpineProperties } from './spine.js';

export type SourceSystem = 'openproject' | 'jira' | 'msproject' | 'planview';

export interface MappedType {
  label: SpineLabel;
  /** Dialect class for provenance, e.g. "safe:Epic", "pmbok:Activity". */
  dialectClass: string;
}

type TypeMap = Record<string, MappedType>;

// ── Native type -> spine, per source (bridging.ttl "External System Aliases") ──

const OPENPROJECT_TYPES: TypeMap = {
  Epic: { label: 'Epic', dialectClass: 'safe:Epic' },
  Capability: { label: 'Feature', dialectClass: 'safe:Capability' },
  Feature: { label: 'Feature', dialectClass: 'safe:Feature' },
  'User Story': { label: 'Story', dialectClass: 'safe:Story' },
  Story: { label: 'Story', dialectClass: 'safe:Story' },
  Task: { label: 'Task', dialectClass: 'pm:Task' },
  Bug: { label: 'Issue', dialectClass: 'pm:Issue' },
  Risk: { label: 'Risk', dialectClass: 'pm:Risk' },
  Milestone: { label: 'Milestone', dialectClass: 'pm:Milestone' },
  Phase: { label: 'Program', dialectClass: 'pm:Program' },
  'Agent Alert': { label: 'Insight', dialectClass: 'k360:AgentFinding' },
  'Governance Gate': { label: 'Milestone', dialectClass: 'k360:ComplianceCheckpoint' },
  'Demand Request': { label: 'Project', dialectClass: 'pm:Project' },
  'Change Request': { label: 'Issue', dialectClass: 'pm:Issue' },
};

const JIRA_TYPES: TypeMap = {
  Initiative: { label: 'Epic', dialectClass: 'safe:Epic' },
  Theme: { label: 'Epic', dialectClass: 'safe:Epic' },
  Epic: { label: 'Epic', dialectClass: 'safe:Epic' },
  Story: { label: 'Story', dialectClass: 'safe:Story' },
  Task: { label: 'Task', dialectClass: 'pm:Task' },
  'Sub-task': { label: 'Task', dialectClass: 'pm:Task' },
  Subtask: { label: 'Task', dialectClass: 'pm:Task' },
  Bug: { label: 'Issue', dialectClass: 'pm:Issue' },
};

const MSPROJECT_TYPES: TypeMap = {
  Project: { label: 'Project', dialectClass: 'pmbok:Project' },
  'Summary Task': { label: 'Deliverable', dialectClass: 'pmbok:WorkPackage' },
  Task: { label: 'Task', dialectClass: 'pmbok:Activity' },
  Milestone: { label: 'Milestone', dialectClass: 'pm:Milestone' },
  Resource: { label: 'Resource', dialectClass: 'pm:Resource' },
};

const PLANVIEW_TYPES: TypeMap = {
  Portfolio: { label: 'Portfolio', dialectClass: 'pm:Portfolio' },
  Program: { label: 'Program', dialectClass: 'pm:Program' },
  Project: { label: 'Project', dialectClass: 'pm:Project' },
  Work: { label: 'Project', dialectClass: 'pm:Project' },
  Task: { label: 'Task', dialectClass: 'pm:Task' },
  Activity: { label: 'Task', dialectClass: 'pm:Task' },
  Milestone: { label: 'Milestone', dialectClass: 'pm:Milestone' },
  Resource: { label: 'Resource', dialectClass: 'pm:Resource' },
  Strategy: { label: 'Objective', dialectClass: 'k360:Objective' },
  Outcome: { label: 'Objective', dialectClass: 'k360:Objective' },
  Investment: { label: 'Project', dialectClass: 'pm:Project' },
  Demand: { label: 'Project', dialectClass: 'pm:Project' },
};

const TYPE_MAPS: Record<SourceSystem, TypeMap> = {
  openproject: OPENPROJECT_TYPES,
  jira: JIRA_TYPES,
  msproject: MSPROJECT_TYPES,
  planview: PLANVIEW_TYPES,
};

const DEFAULT_TYPE: MappedType = { label: 'Task', dialectClass: 'pm:Task' };

/**
 * Reconciliation rules (bridging.ttl §"Reconciliation Rules"). Applied after the
 * static alias lookup; these are conditional and so cannot live in OWL.
 */
function applyReconciliation(base: MappedType, fields: SpineProperties): MappedType {
  // Rule 1: an agile "Task" carrying story points is really a Story.
  if (base.label === 'Task' && typeof fields.storyPoints === 'number' && fields.storyPoints > 0) {
    return { label: 'Story', dialectClass: 'safe:Story' };
  }
  // Rule 2: a "Project" that owns epics behaves as a value stream / program.
  if (base.label === 'Project' && fields['hasEpics'] === true) {
    return { label: 'Program', dialectClass: 'safe:ValueStream' };
  }
  return base;
}

/** Map a source's native type (+ fields for the conditional rules) to the spine. */
export function mapType(
  source: SourceSystem,
  nativeType: string,
  fields: SpineProperties = {},
): MappedType {
  const base = TYPE_MAPS[source]?.[nativeType] ?? DEFAULT_TYPE;
  return applyReconciliation(base, fields);
}

// ── Field normalization (bridging.ttl "Data Source Semantic Reconciliation") ──
// native field name -> canonical SpineProperties key, per source. Used by direct
// adapters; the OpenProject adapter builds SpineProperties from _links directly.

export const FIELD_MAPS: Record<SourceSystem, Record<string, keyof SpineProperties>> = {
  openproject: {
    subject: 'name',
    status: 'status',
    assignee: 'assignee',
    startDate: 'startDate',
    dueDate: 'dueDate',
    percentageDone: 'progress',
  },
  jira: {
    summary: 'name',
    status: 'status',
    assignee: 'assignee',
    duedate: 'dueDate',
    customfield_storypoints: 'storyPoints',
  },
  msproject: {
    Name: 'name',
    Status: 'status',
    Resource: 'assignee',
    Start: 'startDate',
    Finish: 'dueDate',
    PercentComplete: 'progress',
  },
  planview: {
    Title: 'name',
    Status: 'status',
    Owner: 'assignee',
    'Target Finish': 'dueDate',
  },
};

/** Normalize a raw record from a source into canonical SpineProperties. */
export function mapFields(source: SourceSystem, raw: Record<string, unknown>): SpineProperties {
  const map = FIELD_MAPS[source] ?? {};
  const out: SpineProperties = {};
  for (const [nativeKey, value] of Object.entries(raw)) {
    const canonical = map[nativeKey];
    if (canonical) (out as Record<string, unknown>)[canonical] = value;
  }
  return out;
}

/** Stable canonical node id for a source entity (used for cross-tool identity). */
export function canonicalId(source: string, nativeId: string | number): string {
  return `${source}-${nativeId}`;
}

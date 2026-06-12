/**
 * Canonical PPM spine — the framework-neutral vocabulary every source maps onto.
 *
 * Compiled from the Smith Clarity ontology (ontology/modules/core.ttl `pm:` +
 * safe.ttl `safe:`). FalkorDB is a property graph with no OWL reasoner, so the
 * ontology's class hierarchy is *materialized* here: an adapter resolves a
 * source's native type to one spine label (canonicalize-to-spine), and keeps the
 * dialect class (e.g. "safe:Epic") + source as properties for provenance.
 *
 * Keep this list aligned with core.ttl/safe.ttl; it is the contract all adapters
 * (OpenProject, Jira, MS Project, Planview) target.
 */

/** Node labels = `pm:` spine classes (+ a few SAFe/K360 ones we materialize). */
export type SpineLabel =
  // structural hierarchy
  | 'Portfolio'
  | 'Program'
  | 'Project'
  | 'Epic'
  | 'Feature'
  | 'Story'
  | 'Task'
  | 'Issue'
  // supporting concepts
  | 'Risk'
  | 'Milestone'
  | 'Release'
  | 'Deliverable'
  | 'Resource'
  | 'Team'
  // strategy / K360
  | 'Objective'
  | 'KeyResult'
  // agent output
  | 'Insight';

export const SPINE_LABELS: readonly SpineLabel[] = [
  'Portfolio', 'Program', 'Project', 'Epic', 'Feature', 'Story', 'Task', 'Issue',
  'Risk', 'Milestone', 'Release', 'Deliverable', 'Resource', 'Team', 'Objective', 'KeyResult', 'Insight',
] as const;

/** Relationship types = `pm:` object properties, materialized as edge types. */
export type SpineRelationship =
  | 'CONTAINS' // generic parent -> child containment (Project -> work item)
  | 'HAS_FEATURE' // Epic -> Feature
  | 'HAS_STORY' // Feature -> Story
  | 'DEPENDS_ON' // work -> work (pm:dependsOn)
  | 'ASSIGNED_TO' // work -> Resource (pm:isAssignedTo)
  | 'BELONGS_TO_PORTFOLIO'
  | 'BELONGS_TO_PROGRAM'
  | 'CONTRIBUTES_TO' // work -> Objective (k360 OKR alignment)
  | 'HAS_RISK' // work/Project -> Risk
  // dependency edges (canonicalized from source relation types, original kept on `opType`)
  | 'BLOCKS' // work -> work it blocks
  | 'FOLLOWS' // work -> the work it comes after ('precedes' is stored reversed)
  | 'RELATES_TO' // generic association
  | 'DUPLICATES' // work -> the work it duplicates
  // release edges
  | 'HAS_RELEASE' // Project -> Release
  | 'TARGETS_RELEASE'; // work -> Release (fix version)

/**
 * Canonical property names (compiled from core.ttl datatype properties).
 * Adapters map each source's native fields onto these so a Jira `summary`,
 * an MSP `Name`, and a Planview `Title` all land on `name`.
 */
export interface SpineProperties {
  name?: string;
  description?: string;
  status?: string;
  priority?: string;
  assignee?: string;
  startDate?: string;
  endDate?: string;
  dueDate?: string;
  progress?: number; // pm:completionPercentage
  estimatedHours?: number; // pm:effortHours
  actualHours?: number;
  storyPoints?: number; // pm:storyPoints
  [extra: string]: unknown;
}

/** Provenance every node carries so we never lose where it came from. */
export interface Provenance {
  /** True origin system, e.g. "openproject", "jira", "msproject", "planview". */
  source: string;
  /** Which system physically ingested it (the hub). Usually "openproject". */
  ingestedVia: string;
  /** The source's native type string, e.g. "User Story", "Bug", "Summary Task". */
  nativeType: string;
  /** Native id in the source system, for cross-tool reconciliation. */
  nativeId?: string;
  /** The dialect class chosen, e.g. "safe:Epic", "pmbok:Activity". */
  dialectClass: string;
}

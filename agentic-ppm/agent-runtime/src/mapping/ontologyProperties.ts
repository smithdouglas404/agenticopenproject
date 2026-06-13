/**
 * Canonical ontology properties — the targets a source field can map onto.
 *
 * NEW BUILD. Derived from the PPM spine (src/ontology/spine.ts SpineProperties)
 * plus the computed/grounding metrics the runtime produces (risk score, budget
 * variance). ids stay namespaced (pm:/safe:/k360:) so the dialect is explicit.
 * This is the read-only catalog the mapping UI shows on the "map to" side.
 */
import type { OntologyProperty } from './types.js';

/**
 * The ~20 canonical properties. The pm: set mirrors SpineProperties 1:1; the
 * computed ones (riskScore, budgetVariance, …) are what the grounding layer
 * derives, exposed here so a source field can be mapped straight onto them.
 */
const ONTOLOGY_PROPERTIES: readonly OntologyProperty[] = [
  // ── core spine datatype properties (core.ttl pm:) ──
  { id: 'pm:name', label: 'Name', type: 'string', description: 'Title/subject of the work item.' },
  { id: 'pm:description', label: 'Description', type: 'string', description: 'Free-text description.' },
  { id: 'pm:status', label: 'Status', type: 'enum', description: 'Workflow state (New, In Progress, Closed, …).' },
  { id: 'pm:priority', label: 'Priority', type: 'enum', description: 'Relative urgency (Low, Normal, High, …).' },
  { id: 'pm:assignee', label: 'Assignee', type: 'user', description: 'Person responsible for the work.' },
  { id: 'pm:startDate', label: 'Start Date', type: 'date', description: 'Planned/actual start.' },
  { id: 'pm:endDate', label: 'End Date', type: 'date', description: 'Planned/actual finish.' },
  { id: 'pm:dueDate', label: 'Due Date', type: 'date', description: 'Deadline / target finish.' },
  { id: 'pm:percentComplete', label: 'Percent Complete', type: 'percentage', description: 'Completion progress 0–100.' },
  { id: 'pm:effortHours', label: 'Estimated Effort (h)', type: 'duration', description: 'Estimated effort in hours.' },
  { id: 'pm:actualHours', label: 'Actual Effort (h)', type: 'duration', description: 'Spent effort in hours.' },
  { id: 'pm:storyPoints', label: 'Story Points', type: 'number', description: 'Agile sizing estimate.' },
  // ── supporting / structural ──
  { id: 'pm:type', label: 'Type', type: 'enum', description: 'Native item type (Task, Bug, Epic, …).' },
  { id: 'pm:parent', label: 'Parent', type: 'hierarchy', description: 'Parent in the work-breakdown hierarchy.' },
  { id: 'pm:dependsOn', label: 'Depends On', type: 'relation', description: 'Cross-item dependency link.' },
  { id: 'pm:release', label: 'Release / Fix Version', type: 'enum', description: 'Target release this work lands in.' },
  // ── computed grounding metrics (derived, never authored) ──
  { id: 'pm:riskScore', label: 'Risk Score', type: 'number', description: 'Computed likelihood×impact risk score.' },
  { id: 'pm:budgetVariance', label: 'Budget Variance', type: 'currency', description: 'Actual vs planned cost variance.' },
  // ── strategy / K360 OKR alignment ──
  { id: 'k360:objective', label: 'Objective', type: 'string', description: 'Strategic objective this contributes to.' },
  { id: 'k360:keyResult', label: 'Key Result', type: 'string', description: 'Measurable key result.' },
] as const;

/** The canonical properties a source attribute can map onto. */
export function listOntologyProperties(): OntologyProperty[] {
  return ONTOLOGY_PROPERTIES.map((p) => ({ ...p }));
}

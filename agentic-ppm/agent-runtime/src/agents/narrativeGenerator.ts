/**
 * Narrative generator — enriches detector findings with LLM-generated prose.
 *
 * Takes a raw DetectorFinding plus graph context (the work item node and its
 * parent project) and calls Claude to produce a polished, actionable narrative.
 * The result is stored on the AgentFinding node so the console can render it
 * as the primary display text alongside a clickable project link.
 *
 * Falls back gracefully to the detector body if the LLM call fails, so the
 * pipeline is never blocked by a narrative generation error.
 */
import { callLLMJson } from '../llm/claude.js';
import type { DetectorFinding } from './detectors.js';

export interface WorkItemContext {
  /** Stable graph node id, e.g. "op-wp-42". */
  nodeId: string;
  /** Display name of the work item. */
  name: string;
  /** Current status string, e.g. "In Progress". */
  status?: string;
  /** Priority string, e.g. "High". */
  priority?: string;
  /** ISO date string for the due date, if any. */
  endDate?: string;
  /** Assignee name, if any. */
  assignee?: string;
}

export interface ProjectContext {
  /** OpenProject numeric project ID. */
  projectId: number;
  /** Display name of the project. */
  projectName: string;
  /** Total number of work items contained in this project. */
  workItemCount: number;
}

export interface NarrativeResult {
  /** 2-3 sentence polished narrative for display in the console. */
  narrative: string;
  /** OpenProject project ID for the "View in OpenProject" link. */
  projectId?: number;
  /** Human-readable project name. */
  projectName?: string;
}

const SYSTEM_PROMPT = `You are a senior project management advisor writing concise, actionable findings for a human-in-the-loop project oversight console.

Given a detector finding and its graph context, produce a polished narrative that:
- Is exactly 2-3 sentences in professional, direct tone
- Names the specific work item and project
- Explains why this matters to the project (reference the graph context where relevant)
- Ends with a concrete, specific recommended action

Respond with a JSON object matching this schema exactly:
{
  "narrative": "<2-3 sentence narrative string>"
}

Do not include any text outside the JSON object.`;

/**
 * Generate a polished LLM narrative for a detector finding.
 *
 * @param finding  The raw detector finding.
 * @param workItem Graph context for the work item node.
 * @param project  Graph context for the parent project (may be undefined for orphaned items).
 * @returns        Narrative result with prose and project link metadata.
 */
export async function generateNarrative(
  finding: DetectorFinding,
  workItem: WorkItemContext,
  project?: ProjectContext,
): Promise<NarrativeResult> {
  const projectLine = project
    ? `Parent project: "${project.projectName}" (ID ${project.projectId}), which contains ${project.workItemCount} work item(s) in total.`
    : 'This work item has no parent project — it is orphaned in the graph.';

  const contextLines = [
    `Finding type: ${finding.type}`,
    `Severity: ${finding.severity}`,
    `Work item: "${workItem.name}" (node: ${workItem.nodeId})`,
    workItem.status ? `Status: ${workItem.status}` : null,
    workItem.priority ? `Priority: ${workItem.priority}` : null,
    workItem.endDate ? `Due date: ${workItem.endDate}` : null,
    workItem.assignee ? `Assignee: ${workItem.assignee}` : 'Assignee: unassigned',
    projectLine,
    `Detector message: ${finding.body}`,
  ]
    .filter(Boolean)
    .join('\n');

  try {
    const result = await callLLMJson<{ narrative: string }>(
      SYSTEM_PROMPT,
      `Generate a narrative for this finding:\n\n${contextLines}`,
      { maxTokens: 300, temperature: 0.3 },
    );

    return {
      narrative: result.narrative,
      projectId: project?.projectId,
      projectName: project?.projectName,
    };
  } catch (err: any) {
    // Graceful fallback: return the raw detector body so the pipeline is never blocked.
    console.warn(`[narrativeGenerator] LLM call failed, using detector body as fallback: ${err.message}`);
    return {
      narrative: finding.body,
      projectId: project?.projectId,
      projectName: project?.projectName,
    };
  }
}

/**
 * Fetch work item context from the graph for a given node id.
 * Returns null if the node is not found.
 */
export async function fetchWorkItemContext(
  nodeId: string,
): Promise<WorkItemContext | null> {
  const { getGraph } = await import('../graph/falkor.js');
  const rows = await getGraph().query<{
    id: string;
    name: string;
    status?: string;
    priority?: string;
    endDate?: string;
    assignee?: string;
  }>(
    `MATCH (w { id: $nodeId }) RETURN w.id AS id, w.name AS name,
     w.status AS status, w.priority AS priority,
     w.endDate AS endDate, w.assignee AS assignee
     LIMIT 1`,
    { nodeId },
  );
  if (!rows.length) return null;
  const r = rows[0];
  return {
    nodeId: r.id,
    name: r.name ?? nodeId,
    status: r.status || undefined,
    priority: r.priority || undefined,
    endDate: r.endDate || undefined,
    assignee: r.assignee || undefined,
  };
}

/**
 * Fetch the parent project context for a work item node.
 * Returns undefined if the work item has no parent project.
 */
export async function fetchProjectContext(
  nodeId: string,
): Promise<ProjectContext | undefined> {
  const { getGraph } = await import('../graph/falkor.js');

  // Find the project that CONTAINS this work item.
  const projectRows = await getGraph().query<{
    projectId: string;
    projectName: string;
  }>(
    `MATCH (p:Project)-[:CONTAINS]->(w { id: $nodeId })
     RETURN p.id AS projectId, p.name AS projectName
     LIMIT 1`,
    { nodeId },
  );
  if (!projectRows.length) return undefined;

  const { projectId: rawProjectId, projectName } = projectRows[0];

  // Extract the numeric OpenProject project ID from the node id (e.g. "op-project-7" -> 7).
  const numericId = rawProjectId?.match(/op-project-(\d+)/)?.[1];
  const projectId = numericId ? Number(numericId) : 0;

  // Count all work items in this project for graph context.
  const countRows = await getGraph().query<{ c: number }>(
    `MATCH (p:Project { id: $projectId })-[:CONTAINS]->(w)
     RETURN count(w) AS c`,
    { projectId: rawProjectId },
  );
  const workItemCount = countRows[0]?.c ?? 0;

  return {
    projectId,
    projectName: projectName ?? rawProjectId,
    workItemCount,
  };
}

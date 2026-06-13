/**
 * Domain + collaboration contract for the consolidated agent system.
 *
 * Ported from the Kyndral-365 deep agents (server/agents/attributes/*AgentAttributes.ts
 * + server/lib/AgentObjectModel.ts). These are the SAME declarative structures the
 * deep agents used — attributes (what an agent measures), rules (conditions ->
 * actions incl. trigger_agent), and the connection graph (who reacts to whom).
 *
 * The agent-runtime consumes these to run agents EVENT-DRIVEN + RELEVANCE-GATED:
 * an agent runs only when a change touches an attribute it watches, and it talks
 * to other agents via the connection graph / trigger_agent actions — never on a
 * timer.
 */

export type AttributeType = 'number' | 'percentage' | 'currency' | 'enum' | 'boolean' | 'text';
export type AttributeSource = 'calculated' | 'project_field' | 'external_api';

export interface AgentAttribute {
  name: string;
  displayName: string;
  type: AttributeType;
  description?: string;
  unit?: string;
  source: AttributeSource;
  /** How to resolve the value from a graph node / computed metrics. */
  sourcePath?: string;
  values?: string[];
  defaultThresholds?: { warning?: number | string; critical?: number | string };
}

export type RuleOperator = '>' | '<' | '>=' | '<=' | '==' | '!=';
export type RuleActionType = 'alert' | 'escalate' | 'trigger_agent' | 'block' | 'notify';
export type Severity = 'low' | 'medium' | 'high' | 'critical';

export interface DomainRuleCondition {
  attribute: string;
  operator: RuleOperator;
  threshold: number | string;
}

export interface DomainRuleAction {
  type: RuleActionType;
  /** For trigger_agent / escalate: the agents to hand off to (a2a). */
  targetAgents?: string[];
  targetUsers?: string[];
  severity: Severity;
  message?: string;
}

export interface DomainRule {
  id: string;
  name: string;
  description?: string;
  enabled: boolean;
  conditions: DomainRuleCondition[];
  actions: DomainRuleAction[];
}

/** Everything one agent knows about its domain. */
export interface DomainPack {
  /** Roster id, e.g. 'finops', 'governance', 'vro'. */
  agentId: string;
  /** Plain-language capabilities (from the deep agent config). */
  capabilities: string[];
  /** Metric/attribute definitions the agent measures. */
  attributes: Record<string, AgentAttribute>;
  /** Deterministic rules: conditions -> actions (incl. a2a trigger_agent). */
  rules: DomainRule[];
}

export type ConnectionType =
  | 'subscribes_to'
  | 'provides_to'
  | 'collaborates_with'
  | 'escalates_to'
  | 'depends_on';

/** An edge in the agent collaboration graph (from AgentObjectModel). */
export interface AgentConnection {
  fromAgent: string;
  toAgent: string;
  connectionType: ConnectionType;
  /** Attributes that flow across this edge; '*' = all. */
  attributes: string[];
  bidirectional?: boolean;
}

/** A change observed on an entity (from a webhook / CRUD diff). Drives everything. */
export interface ChangeEvent {
  /** Graph node id, e.g. 'op-wp-42' / 'op-project-7'. */
  nodeId: string;
  /** Ontology class / spine label, e.g. 'safe:Epic', 'pm:Project'. */
  ontologyClass?: string;
  /** Which attributes changed and how (prev -> next). Keys are attribute names. */
  changed: Record<string, { prev: unknown; next: unknown }>;
  source?: string;
}

/** A fact one agent broadcasts; subscribers react (relevance-gated). */
export interface AgentFact {
  entity: string;
  attribute: string;
  value: unknown;
  confidence: number;
  byAgent: string;
  at: string;
}

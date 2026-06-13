/**
 * Notification domain pack — ported from Kyndral DeepNotificationAgent.
 * Routing, escalation paths, alert delivery, signal broadcasting, HITL approvals.
 *
 * No AttributeDefinition file exists for Notification in Kyndral; attributes inferred
 * from the deep agent's capabilities/tools. No declarative rules in source.
 */
import type { DomainPack } from './types.js';

export const notificationPack: DomainPack = {
  agentId: 'notification',
  capabilities: [
    'palantir_actions',
    'notifications',
    'hitl_approvals',
    'signal_broadcasting',
    'action_logging',
  ],
  attributes: {
    pending_approvals_count: { name: 'pending_approvals_count', displayName: 'Pending Approvals Count', type: 'number', description: 'Number of HITL approvals awaiting a human decision', unit: 'count', source: 'calculated', defaultThresholds: { warning: 5, critical: 10 } },
    escalation_required: { name: 'escalation_required', displayName: 'Escalation Required', type: 'boolean', description: 'Whether an alert requires escalation to a human/console', source: 'calculated', defaultThresholds: {} },
    delivery_status: { name: 'delivery_status', displayName: 'Delivery Status', type: 'enum', description: 'Status of alert/notification delivery', values: ['pending', 'delivered', 'failed', 'acknowledged'], source: 'calculated', defaultThresholds: {} },
  },
  rules: [],
};

export default notificationPack;

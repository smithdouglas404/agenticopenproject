/**
 * Widget catalog — which render widgets suit which attribute type.
 *
 * NEW BUILD. The mapping UI uses this to offer a sensible widget per mapped
 * attribute (a percentage → progress bar, a date → timeline, an enum → badge).
 * Pure data + a lookup; no rendering happens here (that lives in the Kyndral UI).
 */
import type { AttributeType, WidgetDescriptor } from './types.js';

/** Every widget, keyed implicitly by the attribute types it applies to. */
export const WIDGET_CATALOG: WidgetDescriptor[] = [
  // number / currency
  { id: 'kpi_tile', label: 'KPI Tile', appliesTo: ['number', 'currency'] },
  { id: 'gauge', label: 'Gauge', appliesTo: ['number', 'currency'] },
  { id: 'sparkline', label: 'Sparkline', appliesTo: ['number', 'currency'] },
  { id: 'trend', label: 'Trend', appliesTo: ['number', 'currency'] },
  // percentage
  { id: 'progress_bar', label: 'Progress Bar', appliesTo: ['percentage'] },
  { id: 'rag_ring', label: 'RAG Ring', appliesTo: ['percentage'] },
  // date
  { id: 'timeline', label: 'Timeline', appliesTo: ['date'] },
  { id: 'gantt_bar', label: 'Gantt Bar', appliesTo: ['date'] },
  { id: 'countdown', label: 'Countdown', appliesTo: ['date'] },
  // enum / status
  { id: 'badge', label: 'Badge', appliesTo: ['enum'] },
  { id: 'donut', label: 'Donut', appliesTo: ['enum'] },
  { id: 'kanban_column', label: 'Kanban Column', appliesTo: ['enum'] },
  // boolean
  { id: 'flag_chip', label: 'Flag Chip', appliesTo: ['boolean'] },
  // hierarchy
  { id: 'wbs_tree', label: 'WBS Tree', appliesTo: ['hierarchy'] },
  // relation
  { id: 'dependency_graph', label: 'Dependency Graph', appliesTo: ['relation'] },
  // user / list
  { id: 'assignee_chip', label: 'Assignee Chip', appliesTo: ['user', 'list'] },
  { id: 'workload_heatmap', label: 'Workload Heatmap', appliesTo: ['user', 'list'] },
  // string
  { id: 'labeled_field', label: 'Labeled Field', appliesTo: ['string'] },
  { id: 'markdown_card', label: 'Markdown Card', appliesTo: ['string'] },
  // duration is effort-shaped — reuse the numeric widgets.
  { id: 'duration_bar', label: 'Duration Bar', appliesTo: ['duration'] },
];

/** Widgets that can render a given attribute type. */
export function widgetsForType(type: AttributeType): WidgetDescriptor[] {
  return WIDGET_CATALOG.filter((w) => w.appliesTo.includes(type));
}

/** The default (first-listed) widget id for a type, or undefined if none applies. */
export function defaultWidgetForType(type: AttributeType): string | undefined {
  return widgetsForType(type)[0]?.id;
}

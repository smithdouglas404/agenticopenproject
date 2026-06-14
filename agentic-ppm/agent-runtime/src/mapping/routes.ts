/**
 * Mapping API — read/write surface for the universal mapper.
 *
 * NEW BUILD. Mounted onto the console router (which already applies optional
 * Bearer auth on /api). These are deterministic grounding endpoints the Kyndral
 * UI consumes to discover a source's attributes, see the ontology targets +
 * widget catalog, and read/write the per-source mapping set.
 *
 *   GET  /api/sources                  AdapterSummary[] (every registered source)
 *   GET  /api/sources/:id/schema       discovered AttributeDescriptor[] for a source
 *   GET  /api/sources/:id/tools        MCP tools for a source (else [])
 *   GET  /api/openproject/schema       discovered AttributeDescriptor[] (alias of sources/openproject/schema)
 *   GET  /api/ontology/properties      OntologyProperty[]
 *   GET  /api/widgets                  { widgets: WidgetDescriptor[] }
 *   GET  /api/mapping?source=…         SourceMappingSet (seeded default if unsaved)
 *   POST /api/mapping                  body = SourceMappingSet -> { ok: true }
 *
 * Every handler degrades gracefully: on failure it returns a sane default/empty
 * payload plus an `error` field, never a 500 crash.
 */
import type { Router } from 'express';
import { discoverSchema } from '../openproject/schema.js';
import { getAdapter, listAdapters } from '../adapters/registry.js';
import { listOntologyProperties } from './ontologyProperties.js';
import { WIDGET_CATALOG } from './widgets.js';
import { getMapping, saveMapping } from './store.js';
import { buildMetricsCatalog } from './metricsCatalog.js';
import type { SourceMappingSet } from './types.js';

/** Mount the mapping endpoints onto an existing router. */
export function mountMappingRoutes(router: Router): void {
  // Every registered source the studio can target (pluggable: OP, REST stubs, MCP).
  router.get('/api/sources', (_req, res) => {
    try {
      res.json(listAdapters());
    } catch (err: any) {
      res.json({ sources: [], error: err?.message ?? String(err) });
    }
  });

  // Generic per-source schema discovery (the OP alias below delegates here).
  router.get('/api/sources/:id/schema', async (req, res) => {
    const adapter = getAdapter(req.params.id);
    if (!adapter) {
      res.json({ attributes: [], error: `unknown source: ${req.params.id}` });
      return;
    }
    try {
      res.json(await adapter.discoverSchema());
    } catch (err: any) {
      res.json({ attributes: [], error: err?.message ?? String(err) });
    }
  });

  // MCP TOOLS (candidate agent ACTIONS) for a source; [] for non-MCP sources.
  router.get('/api/sources/:id/tools', async (req, res) => {
    const adapter = getAdapter(req.params.id);
    if (!adapter?.listTools) {
      res.json([]);
      return;
    }
    try {
      res.json(await adapter.listTools());
    } catch (err: any) {
      res.json({ tools: [], error: err?.message ?? String(err) });
    }
  });

  // Back-compat alias — keep the original OpenProject schema endpoint working.
  router.get('/api/openproject/schema', async (_req, res) => {
    try {
      res.json(await discoverSchema());
    } catch (err: any) {
      res.json({ attributes: [], error: err?.message ?? String(err) });
    }
  });

  router.get('/api/ontology/properties', (_req, res) => {
    try {
      res.json(listOntologyProperties());
    } catch (err: any) {
      res.json({ properties: [], error: err?.message ?? String(err) });
    }
  });

  router.get('/api/widgets', (_req, res) => {
    res.json({ widgets: WIDGET_CATALOG });
  });

  // Every resolvable metric/attribute (standard + computed + mapped custom) so
  // the Kyndral RulesPanel metric picker and the widget palette can offer them.
  // The 'agent' kind (agent_attributes) is merged in by the Kyndral proxy.
  router.get('/api/metrics-catalog', async (req, res) => {
    const source = String(req.query.source ?? 'openproject');
    try {
      res.json({ metrics: await buildMetricsCatalog(source) });
    } catch (err: any) {
      res.json({ metrics: [], error: err?.message ?? String(err) });
    }
  });

  router.get('/api/mapping', async (req, res) => {
    const source = String(req.query.source ?? 'openproject');
    try {
      res.json(await getMapping(source));
    } catch (err: any) {
      res.json({ source, mappings: [], updatedAt: new Date().toISOString(), error: err?.message ?? String(err) });
    }
  });

  router.post('/api/mapping', async (req, res) => {
    const set = req.body as SourceMappingSet;
    if (!set || typeof set.source !== 'string' || !Array.isArray(set.mappings)) {
      res.status(400).json({ ok: false, error: 'body must be a SourceMappingSet { source, mappings[] }' });
      return;
    }
    try {
      await saveMapping(set);
      res.json({ ok: true });
    } catch (err: any) {
      res.json({ ok: false, error: err?.message ?? String(err) });
    }
  });
}

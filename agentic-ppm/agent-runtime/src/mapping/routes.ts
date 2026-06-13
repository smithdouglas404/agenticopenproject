/**
 * Mapping API — read/write surface for the universal mapper.
 *
 * NEW BUILD. Mounted onto the console router (which already applies optional
 * Bearer auth on /api). These are deterministic grounding endpoints the Kyndral
 * UI consumes to discover a source's attributes, see the ontology targets +
 * widget catalog, and read/write the per-source mapping set.
 *
 *   GET  /api/openproject/schema       discovered AttributeDescriptor[]
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
import { listOntologyProperties } from './ontologyProperties.js';
import { WIDGET_CATALOG } from './widgets.js';
import { getMapping, saveMapping } from './store.js';
import type { SourceMappingSet } from './types.js';

/** Mount the mapping endpoints onto an existing router. */
export function mountMappingRoutes(router: Router): void {
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

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
import { listOntologyProperties } from './ontologyProperties.js';
import { WIDGET_CATALOG } from './widgets.js';
import { getMapping, saveMapping } from './store.js';
import { buildMetricsCatalog } from './metricsCatalog.js';
import type { AttributeMapping, SourceMappingSet } from './types.js';
import { listSources, discoverSchemaFor, getAdapter } from '../sources/registry.js';

/** Invert a forward ingest transform for write-back (best-effort). */
function reverseTransform(transform: AttributeMapping['transform'], value: unknown): unknown {
  if (transform === 'iso_duration_hours') {
    const hours = typeof value === 'number' ? value : Number(value);
    return Number.isFinite(hours) ? `PT${hours}H` : value; // hours → ISO-8601 duration
  }
  // status_map / priority_map are enum normalizations without a stored inverse;
  // pass the value through (the source usually accepts its own canonical name).
  return value;
}

/** Mount the mapping endpoints onto an existing router. */
export function mountMappingRoutes(router: Router): void {
  // The sources the universal mapper can map (hub-and-spoke), with configured flags.
  router.get('/api/sources', (_req, res) => {
    res.json(listSources());
  });

  // Generalized schema discovery for ANY source (?source=openproject|jira|ado|servicenow|mcp).
  router.get('/api/schema', async (req, res) => {
    const source = String(req.query.source ?? 'openproject');
    try {
      res.json(await discoverSchemaFor(source));
    } catch (err: any) {
      res.json({ attributes: [], error: err?.message ?? String(err) });
    }
  });

  // Back-compat alias for OpenProject, now served through the source registry.
  router.get('/api/openproject/schema', async (_req, res) => {
    try {
      res.json(await discoverSchemaFor('openproject'));
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

  /**
   * Bidirectional edit (write-back): push a value to a source object. Body is
   * either { source, objectId, fields:{sourceKey:value} } (direct) or
   * { source, objectId, ontologyProperty, value } (resolved through the saved
   * mapping + reverse transform — consumers speak ontology, not source keys).
   * The adapter talks to the source; the OpenProject adapter echo-guards its write.
   */
  router.post('/api/writeback', async (req, res) => {
    const body = (req.body ?? {}) as {
      source?: string;
      objectId?: string | number;
      fields?: Record<string, unknown>;
      ontologyProperty?: string;
      value?: unknown;
    };
    const source = String(body.source ?? '');
    const objectId = body.objectId != null ? String(body.objectId) : '';
    if (!source || !objectId) {
      res.status(400).json({ ok: false, error: 'body requires { source, objectId, (fields | ontologyProperty+value) }' });
      return;
    }
    const adapter = getAdapter(source);
    if (!adapter) {
      res.status(404).json({ ok: false, error: `unknown source "${source}"` });
      return;
    }
    if (!adapter.applyUpdate) {
      res.status(501).json({ ok: false, error: `source "${source}" has no write-back capability` });
      return;
    }

    let fields: Record<string, unknown> = {};
    if (body.fields && typeof body.fields === 'object') {
      fields = body.fields;
    } else if (body.ontologyProperty) {
      const set = await getMapping(source).catch(() => null);
      const m = set?.mappings.find((x: AttributeMapping) => x.ontologyProperty === body.ontologyProperty);
      if (!m) {
        res.status(400).json({ ok: false, error: `no mapping for ontology property "${body.ontologyProperty}" on ${source}` });
        return;
      }
      fields = { [m.sourceKey]: reverseTransform(m.transform, body.value) };
    } else {
      res.status(400).json({ ok: false, error: 'provide either fields or ontologyProperty+value' });
      return;
    }

    try {
      const result = await adapter.applyUpdate(objectId, fields);
      res.status(result.ok ? 200 : 502).json(result);
    } catch (err: any) {
      res.status(502).json({ ok: false, source, objectId, error: err?.message ?? String(err) });
    }
  });
}

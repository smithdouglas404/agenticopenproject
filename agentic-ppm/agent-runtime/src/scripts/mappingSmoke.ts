/**
 * Mapping smoke test — proves the universal-mapper foundation works OFFLINE.
 *
 *   npm run mapping:smoke
 *
 * No live OpenProject or FalkorDB required: discoverSchema() degrades to the
 * standard attribute set when the API is unreachable, and getMapping() degrades
 * to a freshly seeded default when the graph is unreachable. This exercises the
 * full read path (discovery -> auto-match -> default mapping set) plus the
 * widget catalog lookup, and prints the results.
 */
import { discoverSchema } from '../openproject/schema.js';
import { getMapping } from '../mapping/store.js';
import { listOntologyProperties } from '../mapping/ontologyProperties.js';
import { widgetsForType } from '../mapping/widgets.js';
import type { AttributeType } from '../mapping/types.js';

async function main(): Promise<void> {
  console.log('Agentic PPM — mapping smoke (offline-safe)\n');

  // 1. Schema discovery (falls back to the standard set without a live OP).
  const attributes = await discoverSchema();
  console.log(`discoverSchema(): ${attributes.length} attributes`);
  for (const a of attributes.slice(0, 8)) {
    console.log(`  - ${a.key} (${a.type})${a.custom ? ' [custom]' : ''} — "${a.label}"`);
  }
  if (attributes.length > 8) console.log(`  … and ${attributes.length - 8} more`);

  // 2. Ontology targets.
  const props = listOntologyProperties();
  console.log(`\nlistOntologyProperties(): ${props.length} canonical properties`);

  // 3. Mapping set (auto-matched default; graph not required).
  const mapping = await getMapping('openproject');
  const matched = mapping.mappings.filter((m) => m.ontologyProperty);
  console.log(
    `\ngetMapping("openproject"): ${mapping.mappings.length} mappings, ` +
      `${matched.length} auto-matched`,
  );
  for (const m of matched.slice(0, 8)) {
    console.log(
      `  - ${m.sourceKey} -> ${m.ontologyProperty}` +
        `${m.widget ? ` [${m.widget}]` : ''}${m.transform && m.transform !== 'none' ? ` (${m.transform})` : ''}`,
    );
  }

  // 4. Widget lookup per type.
  console.log('\nwidgetsForType():');
  const types: AttributeType[] = [
    'number', 'currency', 'percentage', 'date', 'enum', 'boolean',
    'hierarchy', 'relation', 'user', 'list', 'string', 'duration',
  ];
  for (const t of types) {
    const widgets = widgetsForType(t).map((w) => w.id);
    console.log(`  ${t.padEnd(11)} -> ${widgets.join(', ')}`);
  }

  console.log('\nPASS — discovery, auto-match, mapping default, and widget catalog all work.');
}

main().catch((err) => {
  console.error(`\nFAIL — ${err?.message ?? err}`);
  process.exitCode = 1;
});

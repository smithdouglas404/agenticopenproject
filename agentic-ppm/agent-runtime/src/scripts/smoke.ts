/**
 * End-to-end smoke test.
 *
 * One command that proves the core path works: create a throwaway work package
 * in OpenProject, project it into the graph (the same code the webhook handler
 * runs), assert the node landed in FalkorDB, then clean up.
 *
 *   npm run smoke
 *
 * Env:
 *   SMOKE_PROJECT_ID  target project (default: first project returned)
 *   SMOKE_TYPE        WP type name to use (default: Task, else first available)
 *   SMOKE_KEEP=1      keep the test work package + node (skip cleanup)
 *
 * Run it ON the Railway sidecar service (it needs to reach OpenProject + FalkorDB).
 * Exit code is non-zero on any failure.
 */
import { config } from '../config.js';
import { getOpenProjectClient } from '../openproject/client.js';
import { getProjector } from '../projector/projector.js';
import { getGraph } from '../graph/falkor.js';
import { closeGraphiti } from '../graph/graphiti.js';

async function main(): Promise<void> {
  const op = getOpenProjectClient();
  const graph = getGraph();

  console.log('Agentic PPM — smoke test\n');

  // 0. Connectivity.
  const conn = await op.testConnection();
  if (!conn.connected) throw new Error(`OpenProject not reachable: ${conn.error}`);
  console.log(`✅ OpenProject: ${conn.instanceName ?? 'instance'} (core ${conn.version ?? '?'})`);

  // 1. Pick a target project.
  const projects = await op.listProjects();
  if (projects.length === 0) throw new Error('No projects found in OpenProject');
  const project =
    (process.env.SMOKE_PROJECT_ID &&
      projects.find((p) => String(p.id) === process.env.SMOKE_PROJECT_ID)) ||
    projects[0];
  console.log(`✅ Project: "${project.name}" (id ${project.id})`);

  // 2. Pick a valid work-package type.
  const types = await op.listTypes();
  if (types.length === 0) throw new Error('No work-package types available');
  const wantType = process.env.SMOKE_TYPE ?? 'Task';
  const type = types.find((t) => t.name === wantType) ?? types[0];
  console.log(`✅ Type: "${type.name}"`);

  // 3. Create a throwaway work package.
  const subject = `[smoke] agentic-ppm ${new Date().toISOString()}`;
  const created = await op.createWorkPackage(project.id, {
    subject,
    _links: { type: { href: type.self } },
  } as any);
  if (!created.id) throw new Error('Work package created but no id returned');
  console.log(`✅ Created WP #${created.id}: "${subject}"`);

  let projectedNodeId: string | undefined;
  try {
    // 4. Project it (same code the webhook handler calls).
    const result = await getProjector().syncSingleWorkPackage(created.id);
    if (!result) throw new Error('Projector skipped the work package (sync_source filter?)');
    projectedNodeId = result.nodeId;
    console.log(`✅ Projected as ${result.label} node "${result.nodeId}"`);

    // 5. Assert the node is in the graph.
    const rows = await graph.query<{ name: string }>(
      'MATCH (n { id: $id }) RETURN n.name AS name',
      { id: result.nodeId },
    );
    if (rows.length === 0) throw new Error(`Node ${result.nodeId} not found in FalkorDB`);
    if (rows[0].name !== subject) {
      throw new Error(`Node name mismatch: expected "${subject}", got "${rows[0].name}"`);
    }
    console.log(`✅ Verified node in FalkorDB graph "${config.falkor.graph}"`);

    console.log('\nPASS — OpenProject → projector → FalkorDB round-trip works.');
  } finally {
    // 6. Cleanup (unless asked to keep).
    if (process.env.SMOKE_KEEP === '1') {
      console.log(`\n(SMOKE_KEEP=1) Left WP #${created.id} and its node in place.`);
    } else {
      if (projectedNodeId) {
        await graph.query('MATCH (n { id: $id }) DETACH DELETE n', { id: projectedNodeId }).catch(() => {});
      }
      await op.deleteWorkPackage(created.id).catch((e) =>
        console.warn(`  cleanup: could not delete WP #${created.id}: ${e.message}`),
      );
      console.log(`\nCleaned up WP #${created.id} and its graph node.`);
    }
  }
}

main()
  .catch((err) => {
    console.error(`\nFAIL — ${err.message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await Promise.allSettled([getGraph().close(), closeGraphiti()]);
  });

/**
 * Manual / opt-in proactive reflection run. Lets the agents look at the graph
 * for opportunities on demand (no cron required). Usage: npm run agents:reflect
 */
import { proactiveReflect } from '../agents/autonomy/proactive.js';

proactiveReflect({ limit: Number(process.env.REFLECT_LIMIT ?? 20) })
  .then((r) => {
    console.log(`done: reflected over ${r.entities} entit(y/ies), ${r.insights} insight(s)`);
    process.exit(0);
  })
  .catch((err) => {
    console.error('reflect failed:', err);
    process.exit(1);
  });

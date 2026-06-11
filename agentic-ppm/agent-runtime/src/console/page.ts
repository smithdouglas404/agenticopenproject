/**
 * Agent Console — single-file HTML UI (Phase 2 HITL surface).
 *
 * Served by the sidecar at /console. Reads /api/roster and /api/findings,
 * lets a human approve/reject findings. No build step, no framework — keeps the
 * console deployable anywhere the sidecar runs.
 */
export const CONSOLE_HTML = /* html */ `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Agentic PPM — Agent Console</title>
<style>
  :root {
    --bg: #0d1117; --panel: #161b22; --border: #30363d; --text: #e6edf3;
    --muted: #8b949e; --accent: #2f81f7; --ok: #3fb950; --warn: #d29922;
    --bad: #f85149; --chip: #21262d;
  }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--bg); color: var(--text);
         font: 14px/1.5 -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
  header { padding: 16px 24px; border-bottom: 1px solid var(--border);
           display: flex; align-items: baseline; gap: 16px; }
  header h1 { font-size: 18px; margin: 0; }
  header .sub { color: var(--muted); font-size: 13px; }
  main { padding: 24px; max-width: 1200px; margin: 0 auto; }
  h2 { font-size: 14px; text-transform: uppercase; letter-spacing: .06em;
       color: var(--muted); margin: 24px 0 12px; }
  .agents { display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr)); gap: 12px; }
  .agent { background: var(--panel); border: 1px solid var(--border); border-radius: 8px; padding: 12px 14px; }
  .agent .name { font-weight: 600; }
  .agent .purpose { color: var(--muted); font-size: 12px; margin-top: 4px; min-height: 34px; }
  .agent .meta { margin-top: 8px; display: flex; gap: 8px; align-items: center; }
  .chip { background: var(--chip); border: 1px solid var(--border); border-radius: 999px;
          padding: 1px 9px; font-size: 11px; color: var(--muted); }
  .chip.active { color: var(--ok); border-color: var(--ok); }
  .chip.open { color: var(--warn); border-color: var(--warn); }
  .filters { display: flex; gap: 8px; margin-bottom: 12px; flex-wrap: wrap; }
  .filters button { background: var(--chip); color: var(--text); border: 1px solid var(--border);
                    border-radius: 6px; padding: 4px 12px; cursor: pointer; font-size: 13px; }
  .filters button.sel { border-color: var(--accent); color: var(--accent); }
  .finding { background: var(--panel); border: 1px solid var(--border); border-radius: 8px;
             padding: 12px 16px; margin-bottom: 10px; }
  .finding .top { display: flex; gap: 10px; align-items: baseline; flex-wrap: wrap; }
  .sev { font-size: 11px; font-weight: 700; border-radius: 4px; padding: 1px 6px; }
  .sev.high, .sev.alarm, .sev.critical { background: #67060c; color: #ffb3ad; }
  .sev.medium, .sev.warning { background: #5a3e02; color: #f0d36a; }
  .sev.low, .sev.notification { background: #0d419d; color: #a5c9ff; }
  .finding .title { font-weight: 600; }
  .finding .body { color: var(--muted); margin: 6px 0; white-space: pre-wrap; }
  .finding .meta { color: var(--muted); font-size: 12px; }
  .actions { margin-top: 8px; display: flex; gap: 8px; }
  .actions button { border-radius: 6px; padding: 4px 14px; cursor: pointer; font-size: 13px;
                    border: 1px solid var(--border); background: var(--chip); color: var(--text); }
  .actions .approve { border-color: var(--ok); color: var(--ok); }
  .actions .reject { border-color: var(--bad); color: var(--bad); }
  .status-pill { font-size: 11px; border-radius: 999px; padding: 1px 9px; border: 1px solid var(--border); }
  .status-approved { color: var(--ok); border-color: var(--ok); }
  .status-rejected { color: var(--bad); border-color: var(--bad); }
  .status-published, .status-new { color: var(--warn); border-color: var(--warn); }
  .empty { color: var(--muted); padding: 24px; text-align: center; }
  a { color: var(--accent); text-decoration: none; }
  .links { margin-top: 6px; font-size: 12px; display: flex; gap: 4px; flex-wrap: wrap; }
  .links a { color: var(--accent); }
  .links a:hover { text-decoration: underline; }
  .link-sep { color: var(--muted); }
</style>
</head>
<body>
<header>
  <h1>⚙︎ Agent Console</h1>
  <span class="sub">Agentic PPM · human-in-the-loop · <span id="updated"></span></span>
  <button id="sweepBtn" style="margin-left:auto; background:var(--chip); color:var(--accent);
    border:1px solid var(--accent); border-radius:6px; padding:4px 14px; cursor:pointer; font-size:13px;">
    ▶ Run sweep
  </button>
</header>
<main>
  <h2>Agents</h2>
  <div class="agents" id="agents"></div>
  <h2>Findings & Recommendations</h2>
  <div class="filters" id="filters"></div>
  <div id="findings"></div>
</main>
<script>
const TOKEN = new URLSearchParams(location.search).get('token') || '';
const HEADERS = TOKEN ? { 'Authorization': 'Bearer ' + TOKEN } : {};
let statusFilter = 'open';

async function api(path, opts) {
  const res = await fetch(path, Object.assign({ headers: HEADERS }, opts));
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text != null) e.textContent = text;
  return e;
}

async function refresh() {
  try {
    const [roster, findings] = await Promise.all([
      api('/api/roster'),
      api('/api/findings' + (statusFilter === 'all' ? '' : '?status=' + statusFilter)),
    ]);
    renderAgents(roster);
    renderFindings(findings);
    document.getElementById('updated').textContent = 'updated ' + new Date().toLocaleTimeString();
  } catch (e) {
    document.getElementById('findings').innerHTML =
      '<div class="empty">Failed to load: ' + e.message + '</div>';
  }
}

function renderAgents(roster) {
  const root = document.getElementById('agents');
  root.innerHTML = '';
  for (const a of roster) {
    const card = el('div', 'agent');
    card.appendChild(el('div', 'name', a.name));
    card.appendChild(el('div', 'purpose', a.purpose));
    const meta = el('div', 'meta');
    meta.appendChild(el('span', 'chip' + (a.status === 'active' ? ' active' : ''), a.status));
    if (a.counts) meta.appendChild(el('span', 'chip open', a.counts.open + ' open / ' + a.counts.total));
    card.appendChild(meta);
    root.appendChild(card);
  }
}

function renderFindings(list) {
  const filters = document.getElementById('filters');
  filters.innerHTML = '';
  for (const f of ['open', 'approved', 'rejected', 'all']) {
    const b = el('button', f === statusFilter ? 'sel' : '', f);
    b.onclick = () => { statusFilter = f; refresh(); };
    filters.appendChild(b);
  }
  const root = document.getElementById('findings');
  root.innerHTML = '';
  if (!list.length) { root.appendChild(el('div', 'empty', 'No findings here. The agents are quiet — or the graph is.')); return; }
  for (const f of list) {
    const card = el('div', 'finding');
    const top = el('div', 'top');
    top.appendChild(el('span', 'sev ' + f.severity, f.severity.toUpperCase()));
    top.appendChild(el('span', 'title', f.title));
    top.appendChild(el('span', 'status-pill status-' + f.status, f.status));
    card.appendChild(top);
    // Prefer the LLM-generated narrative; fall back to the raw detector body.
    card.appendChild(el('div', 'body', f.narrative || f.body));
    const meta = el('div', 'meta');
    meta.textContent = f.agentId + ' · ' + f.type + ' · ' + new Date(f.updatedAt).toLocaleString()
      + (f.alertWpId ? ' · alert WP #' + f.alertWpId : '')
      + (f.followupWpId ? ' · follow-up WP #' + f.followupWpId : '');
    card.appendChild(meta);
    // Render project link and work package link when available.
    if (f.projectId || f.workPackageId) {
      const links = el('div', 'links');
      if (f.projectId && f.projectName) {
        const projectLink = document.createElement('a');
        projectLink.href = '/projects/' + f.projectId;
        projectLink.target = '_blank';
        projectLink.rel = 'noopener noreferrer';
        projectLink.textContent = '↗ ' + f.projectName;
        links.appendChild(projectLink);
      }
      if (f.workPackageId) {
        if (f.projectId) {
          const sep = el('span', 'link-sep', ' · ');
          links.appendChild(sep);
        }
        const wpLink = document.createElement('a');
        wpLink.href = '/work_packages/' + f.workPackageId;
        wpLink.target = '_blank';
        wpLink.rel = 'noopener noreferrer';
        wpLink.textContent = '↗ Work Package #' + f.workPackageId;
        links.appendChild(wpLink);
      }
      card.appendChild(links);
    }
    if (f.status === 'new' || f.status === 'published') {
      const actions = el('div', 'actions');
      const ok = el('button', 'approve', '✓ Approve');
      ok.onclick = () => decide(f.id, 'approve');
      const no = el('button', 'reject', '✕ Reject');
      no.onclick = () => decide(f.id, 'reject');
      actions.appendChild(ok); actions.appendChild(no);
      card.appendChild(actions);
    }
    root.appendChild(card);
  }
}

async function decide(id, action) {
  try {
    await api('/api/findings/' + encodeURIComponent(id) + '/' + action, { method: 'POST' });
    refresh();
  } catch (e) { alert('Failed: ' + e.message); }
}

document.getElementById('sweepBtn').onclick = async () => {
  const btn = document.getElementById('sweepBtn');
  btn.disabled = true; btn.textContent = '… sweeping';
  try {
    const r = await api('/api/sweep', { method: 'POST' });
    btn.textContent = '✓ ' + r.detected + ' detected, ' + r.newFindings + ' new';
    refresh();
  } catch (e) { btn.textContent = '✕ failed'; }
  setTimeout(() => { btn.disabled = false; btn.textContent = '▶ Run sweep'; }, 4000);
};

refresh();
setInterval(refresh, 30000);
</script>
</body>
</html>`;

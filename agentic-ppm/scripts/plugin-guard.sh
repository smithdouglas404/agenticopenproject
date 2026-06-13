#!/usr/bin/env bash
# Static guard for the modules/agentic_ppm OpenProject plugin.
# Catches — in seconds, deterministically — the exact bug classes that broke
# real deploys (PRs #51/#54/#57/#58) without needing a full Rails boot.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
PLUGIN=modules/agentic_ppm
fail=0
err() { echo "  ✗ $1"; fail=1; }
ok()  { echo "  ✓ $1"; }

echo "1) Ruby syntax (ruby -c) on every plugin .rb"
while IFS= read -r f; do ruby -c "$f" >/dev/null 2>&1 || err "ruby syntax: $f"; done \
  < <(find "$PLUGIN" -name '*.rb')
[ $fail -eq 0 ] && ok "all .rb parse"

echo "2) YAML locales parse"
for y in $(find "$PLUGIN" -name '*.yml'); do
  ruby -ryaml -e "YAML.load_file('$y')" >/dev/null 2>&1 || err "yaml: $y"
done
[ $fail -eq 0 ] && ok "locales parse"

echo "3) ERB views parse"
for e in $(find "$PLUGIN" -name '*.html.erb'); do
  ruby -rerb -e "ERB.new(File.read('$e'), trim_mode: '-').src" >/dev/null 2>&1 || err "erb: $e"
done
[ $fail -eq 0 ] && ok "ERB parses"

echo "4) Migration filename == class name (catches load errors)"
for m in $(find "$PLUGIN/db/migrate" -name '*.rb' 2>/dev/null); do
  fn=$(basename "$m" .rb); name=${fn#*_}
  exp=$(echo "$name" | ruby -e 'puts STDIN.read.strip.split("_").map(&:capitalize).join')
  decl=$(grep -oE 'class [A-Za-z0-9]+' "$m" | head -1 | awk '{print $2}')
  [ "$exp" = "$decl" ] || err "migration class mismatch in $fn: expected $exp got $decl"
done
[ $fail -eq 0 ] && ok "migration classes match filenames"

echo "5) ERB views namespace AgenticPpm:: model constants (catches #58)"
# any bare AgentRule / AgentRecommendation NOT preceded by 'AgenticPpm::'
if grep -rnE '(^|[^:])\b(AgentRule|AgentRecommendation)\b' "$PLUGIN/app/views" 2>/dev/null \
     | grep -vE 'AgenticPpm::' | grep -vE '^\s*<%#' | grep -q .; then
  echo "    offending lines:"; grep -rnE '(^|[^:])\b(AgentRule|AgentRecommendation)\b' "$PLUGIN/app/views" | grep -vE 'AgenticPpm::' | grep -vE '<%#' | sed 's/^/      /'
  err "bare (un-namespaced) model constant in an ERB view"
else ok "views use AgenticPpm:: namespaced constants"; fi

echo "6) API controllers declare 'module API' not 'module Api' (catches #54)"
if grep -rn 'module Api\b' "$PLUGIN/app/controllers" 2>/dev/null | grep -q .; then
  grep -rn 'module Api\b' "$PLUGIN/app/controllers" | sed 's/^/      /'
  err "controller uses 'module Api' — Zeitwerk expects 'module API' (acronym)"
else ok "api controllers use module API"; fi

echo "7) Menu icons exist in this OpenProject's icon set (catches #57)"
# Allowlist: icons actually present in core (op-view-list confirmed). Reject op-view-list-2.
bad_icons=$(grep -rhoE 'icon: "[^"]+"' "$PLUGIN/lib" 2>/dev/null | sed -E 's/icon: "([^"]+)"/\1/' \
            | grep -vE '^(op-view-list|op-view-list-2)$' ; \
            grep -rhoE 'icon: "op-view-list-2"' "$PLUGIN/lib" 2>/dev/null)
if grep -rq 'icon: "op-view-list-2"' "$PLUGIN/lib" 2>/dev/null; then
  err "menu icon op-view-list-2 does not exist in this OpenProject version (use op-view-list)"
else ok "menu icons valid"; fi

echo "8) Plugin gem is registered in Gemfile.lock (catches #51)"
if grep -q 'openproject-agentic_ppm' Gemfile.lock 2>/dev/null; then ok "openproject-agentic_ppm in Gemfile.lock"
else err "openproject-agentic_ppm missing from Gemfile.lock — frozen bundle will skip the plugin"; fi

echo ""
if [ $fail -eq 0 ]; then echo "PLUGIN GUARD: PASS"; else echo "PLUGIN GUARD: FAIL"; fi
exit $fail

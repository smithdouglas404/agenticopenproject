import { States } from 'core-app/core/states/states.service';

/**
 * Resolve a work package identifier to its semantic routing ID (e.g. "PROJ-42").
 * Falls back to the input ID if the WP is not in cache or has no displayId —
 * this is a best-effort lookup, not a guarantee. The URL just shows the
 * numeric ID temporarily until the WP is cached.
 *
 * Use this in navigation handlers where the caller only has an identifier
 * string (typically a numeric PK from a data-work-package-id attribute or
 * a selection state) but the URL should show the semantic form.
 */
export function resolveRoutingId(states:States, workPackageId:string):string {
  const wp = states.workPackages.get(workPackageId)?.value;
  return wp?.displayId ?? workPackageId;
}

/**
 * Resolve a URL route parameter (which may be numeric `"42"` or semantic
 * `"PROJ-7"`) to the internal numeric ID we use for cache, selection,
 * focus, and API calls.
 *
 * Returns `null` if the WP can't be found in the cache. Unlike
 * {@link resolveRoutingId}, there is no safe fallback: returning the
 * input unchanged would hand a semantic identifier to code that expects
 * a numeric ID, silently corrupting comparisons and lookups. Callers
 * must handle the `null` case explicitly.
 *
 * The cache is currently keyed only by numeric ID, so semantic route
 * params will reliably miss until the cache is dual-keyed. Treat this
 * helper as a temporary shim around that limitation.
 */
export function resolveNumericId(states:States, routeParam:string):string | null {
  const wp = states.workPackages.get(routeParam)?.value;
  return wp?.id ?? null;
}

/**
 * Relevance gate — the heart of "act only if relevant".
 *
 * WHAT: Given a ChangeEvent, returns the set of agents that have any business
 * reacting to it. An agent is relevant iff a changed attribute is referenced by
 * one of its DomainRule conditions (rulesWatching) OR it subscribes to that
 * attribute via the connection graph (agentsSubscribedTo). Nothing else runs.
 * WHY: This is what makes the engine event-driven, not a polling loop — an agent
 * is woken ONLY by a change it cares about. Attribute names from a webhook diff
 * and from rule/connection declarations rarely agree on case/snake-vs-camel, so
 * matching is tolerant: exact first, then a normalized (lowercase, separator-
 * stripped) compare. Pure + deterministic; never throws.
 */
import type { ChangeEvent } from '../domains/types.js';
import { agentsSubscribedTo, rulesWatching, allWatchedAttributes } from '../domains/index.js';

/** Normalize an attribute name for tolerant matching: lowercase, strip _ and -. */
export function normalizeAttr(name: string): string {
  return name.toLowerCase().replace(/[_\-\s]/g, '');
}

/**
 * The changed attribute names of an event, paired with their canonical (watched)
 * form when one exists. Falls back to the raw key so an exact registry match
 * still works even if the attribute isn't in allWatchedAttributes() yet.
 */
function changedAttributeNames(change: ChangeEvent): string[] {
  return Object.keys(change.changed ?? {});
}

/**
 * Resolve a changed key to the watched-attribute name(s) it matches. Tries an
 * exact hit first, then a normalized compare across every watched attribute.
 */
function watchedMatchesFor(changedKey: string, watched: Set<string>): string[] {
  if (watched.has(changedKey)) return [changedKey];
  const norm = normalizeAttr(changedKey);
  const hits: string[] = [];
  for (const attr of watched) {
    if (normalizeAttr(attr) === norm) hits.push(attr);
  }
  // Also keep the raw key so a registry lookup keyed on the raw name still works
  // even when the attribute is not (yet) in the watched set.
  if (hits.length === 0) hits.push(changedKey);
  return hits;
}

/**
 * The RELEVANCE GATE. Returns the deduped set of agent ids that should run for
 * this change. Empty when nothing watches any changed attribute.
 */
export function agentsForChange(change: ChangeEvent): string[] {
  const watched = allWatchedAttributes();
  const relevant = new Set<string>();

  for (const changedKey of changedAttributeNames(change)) {
    for (const attr of watchedMatchesFor(changedKey, watched)) {
      // (a) agents whose DomainRule conditions reference the attribute
      for (const { agentId } of rulesWatching(attr)) relevant.add(agentId);
      // (b) agents subscribed to the attribute over the connection graph
      for (const agentId of agentsSubscribedTo(attr)) relevant.add(agentId);
    }
  }

  return [...relevant];
}

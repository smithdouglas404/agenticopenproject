//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

export interface MutationCallbacks<E> {
  /** Called for every raw MutationRecord (useful for advanced cases) */
  onAnyRecord?:(record:MutationRecord) => void;

  /** Called for each *matching* element added to the DOM */
  onAdded?:(el:E) => void;

  /** Called for each *matching* element removed from the DOM */
  onRemoved?:(el:E) => void;

  /** Called for attribute changes on *matching* elements */
  onAttributeChange?:(el:Element, attrName:string, oldValue:string|null) => void;

  /** Called for text/characterData changes */
  onTextChange?:(node:CharacterData, oldValue:string|null) => void;
};

export interface MutationHelperOptions {
  /**
   * Only elements that match this selector will trigger onAdded/onRemoved/onAttributeChange.
   * If omitted, all elements are considered matches.
   */
  selector?:string;

  /**
   * Limit attribute callbacks to these names (e.g. ['hidden','aria-expanded']).
   * If omitted, all attributes will trigger callbacks.
   */
  attributeFilter?:string[];

  /**
   * Observer init flags. Reasonable defaults applied if omitted.
   * Defaults:
   *   childList: true, subtree: true, attributes: true, attributeOldValue: true
   */
  observerInit?:MutationObserverInit;

  /**
   * Debounce/coalesce callback execution (ms). Helpful when many mutations fire at once.
   * Set 0 to process synchronously (default 0).
   */
  debounceMs?:number;

  /**
   * Run a one-time scan on init and fire attribute callbacks for existing matches.
   */
  runInitial?:boolean;

  /**
   * When matching elements are added, fire attribute callbacks for attributes already present.
   * (default: true)
   */
  attributeOnAdded?:boolean;
}

/**
 * A tiny MutationObserver helper.
 *
 * Features:
 * - Callbacks for added/removed nodes, attribute changes, and text changes.
 * - Filter elements by CSS selector.
 * - Attribute name filtering.
 * - Debounce/coalesce bursts of mutations.
 * - Utility static helpers for common patterns (observeAdded, observeRemoved, observeOnce).
 */
export class MutationHelper<E extends Element> {
  private observer:MutationObserver;
  private root:Node;
  private selector?:string;
  private attributeFilter?:Set<string>;
  private cbs:MutationCallbacks<E>;
  private debounceMs:number;
  private queuedRecords:MutationRecord[] = [];
  private timer:number|null = null;
  private runInitial:boolean;
  private attributeOnAdded:boolean;
  private init:MutationObserverInit;

  constructor(root:Node, callbacks:MutationCallbacks<E>, opts:MutationHelperOptions = {}) {
    this.root = root;
    this.cbs = callbacks;
    this.selector = opts.selector;
    this.attributeFilter = opts.attributeFilter ? new Set(opts.attributeFilter.map(n => n.toLowerCase())) : undefined;
    this.debounceMs = opts.debounceMs ?? 0;
    this.runInitial = !!opts.runInitial;
    this.attributeOnAdded = opts.attributeOnAdded ?? true;
    this.init = {
      childList: true,
      subtree: true,
      attributes: true,
      attributeOldValue: true,
      characterData: false,
      ...opts.observerInit,
    };

    // If user asked for attributeFilter but forgot to enable attributes, enable them.
    if (this.attributeFilter && !this.init.attributes) {
      this.init.attributes = true;
    }

    this.observer = new MutationObserver((records) => {
      if (this.debounceMs > 0) {
        this.queuedRecords.push(...records);
        this.timer ??= window.setTimeout(() => {
          const batch = this.queuedRecords.splice(0);
          this.timer = null;
          this.process(batch);
        }, this.debounceMs);
      } else {
        this.process(records);
      }
    });
  }

  /** Start observing. */
  observe():void {
    this.observer.observe(this.root, this.init);

    if (this.runInitial && this.cbs.onAttributeChange) {
      this.primeAttributes(this.cbs.onAttributeChange);
    }
  }

  /** Stop observing. Idempotent. */
  disconnect():void {
    if (this.timer != null) {
      window.clearTimeout(this.timer);
      this.timer = null;
    }
    this.queuedRecords.length = 0;
    this.observer.disconnect();
  }

  /** Flush pending records synchronously. */
  flush():void {
    const pending = this.observer.takeRecords();
    if (pending.length) this.process(pending);
  }

  private primeAttributes(cb:(el:Element, attrName:string, oldValue:string|null) => void) {
    const elements = this.selector
      ? (this.root as ParentNode).querySelectorAll(this.selector)
      : (this.root as ParentNode).querySelectorAll('*');
    const attrFilter = this.attributeFilter;

    elements.forEach((el) => {
      const names = attrFilter
        ? [...attrFilter].filter((n) => el.hasAttribute(n))
        : el.getAttributeNames();
      for (const name of names) cb(el, name, null);
    });
  }

  private process(records:MutationRecord[]):void {
    if (!records.length) return;

    const { onAnyRecord, onAdded, onRemoved, onAttributeChange, onTextChange } = this.cbs;
    for (const rec of records) {
      onAnyRecord?.(rec);

      switch (rec.type) {
        case 'childList': {
          if (onAdded && rec.addedNodes.length) {
            for (const node of rec.addedNodes) {
              this.forEachMatchingElement(node, onAdded);
            }
          }
          if (onRemoved && rec.removedNodes.length) {
            for (const node of rec.removedNodes) {
              this.forEachMatchingElement(node, onRemoved);
            }
          }
          // NEW: if elements are added and already have the attribute(s), fire attribute callback
          if (onAttributeChange && this.attributeOnAdded && rec.addedNodes.length) {
            for (const node of rec.addedNodes) {
              this.forEachMatchingElement(node, (el) => {
                const names = this.attributeFilter
                  ? [...this.attributeFilter].filter((n) => el.hasAttribute(n))
                  : el.getAttributeNames(); // if not filtered, report all present attrs
                for (const name of names) {
                  onAttributeChange(el, name, null);
                }
              });
            }
          }
          break;
        }

        case 'attributes': {
          if (!onAttributeChange) break;
          const target = rec.target;
          if (isElement(target) && this.matchesFilter(target)) {
            const attrName = rec.attributeName ?? '';
            if (!this.attributeFilter || this.attributeFilter.has(attrName.toLowerCase())) {
              onAttributeChange(target, attrName, (rec).oldValue ?? null);
            }
          }
          break;
        }

        case 'characterData': {
          if (!onTextChange) break;
          const target = rec.target;
          if (isCharacterData(target)) {
            onTextChange(target, rec.oldValue ?? null);
          }
          break;
        }
      }
    }
  }

  /** True if the element matches the configured selector (or no selector configured). */
  private matchesFilter(el:Element):boolean {
    if (!this.selector) return true;

    return el.matches(this.selector);
  }

  /** Walk the node (and its subtree) and invoke cb for each matching Element. */
  private forEachMatchingElement(node:Node, cb:(el:Element) => void):void {
    if (isElement(node) && this.matchesFilter(node)) cb(node);

    // If it's a DocumentFragment (e.g., from template or range), search inside it.
    const root = node.nodeType === Node.DOCUMENT_FRAGMENT_NODE ? (node as DocumentFragment) : null;
    const ctx:ParentNode|null = (isElement(node) ? (node) : root) ?? null;

    if (ctx) {
      // If we have a selector, querySelectorAll is fast; otherwise walk children as Elements.
      if (this.selector) {
        ctx.querySelectorAll(this.selector).forEach(cb);
      } else {
        // No selector: visit element descendants
        const treeWalker = document.createTreeWalker(ctx, NodeFilter.SHOW_ELEMENT);
        let current:Node|null = treeWalker.currentNode;
        if (isElement(current)) cb(current);
        while ((current = treeWalker.nextNode())) {
          if (isElement(current)) cb(current);
        }
      }
    }
  }

  // ---------- Convenience static helpers ----------

  /**
   * Constructs a `MutationHelper` that observes elements added under `root` matching `selector`,
   * calling `cb` once per element.
   */
  static forAdded<E extends Element>(
    root:Node,
    selector:string,
    cb:(el:E) => void,
    opts:Omit<MutationHelperOptions, 'selector'> = {}
  ) {
    return new MutationHelper<E>(root, { onAdded: cb }, { selector, ...opts });
  }

  /**
   * Constructs a `MutationHelper` that observes elements removed under `root` matching `selector`,
   * calling `cb` once per element.
   */
  static forRemoved<E extends Element>(
    root:Node,
    selector:string,
    cb:(el:E) => void,
    opts:Omit<MutationHelperOptions, 'selector'> = {}
  ) {
    return new MutationHelper<E>(root, { onRemoved: cb }, { selector, ...opts });
  }

  /**
   * Constructs a `MutationHelper` that observes attribute changes for matching elements.
   */
  static forAttributes(
    root:Node,
    selector:string,
    cb:(el:Element, attrName:string, oldValue:string|null) => void,
    opts:Omit<MutationHelperOptions, 'selector'> & { attributeFilter?:string[]; runInitial?:boolean } = {}
  ) {
    return new MutationHelper(
      root,
      { onAttributeChange: cb },
      {
        selector,
        attributeFilter: opts.attributeFilter,
        debounceMs: opts.debounceMs,
        attributeOnAdded: opts.attributeOnAdded ?? true,
        runInitial: opts.runInitial ?? true, // default true for convenience
        observerInit: {
          attributes: true,
          attributeOldValue: true,
          subtree: true,
          childList: true, // important: see elements as they are added
          ...(opts.observerInit ?? {}),
        },
      }
    );
  }

  /**
   * Resolve with the first element added that matches `selector`, then auto-disconnect.
   */
  static observeOnce<E extends Element>(root:Node, selector?:string, opts:Omit<MutationHelperOptions, 'selector'> = {}):Promise<E> {
    return new Promise<E>((resolve) => {
      const helper = new MutationHelper<E>(
        root,
        {
          onAdded: (el) => {
            helper.disconnect();
            resolve(el);
          },
        },
        { selector, ...opts }
      );
      helper.observe();
    });
  }
}

// ---------- Type guards ----------
function isElement(node:Node|null|undefined):node is Element {
  return !!node && node.nodeType === Node.ELEMENT_NODE;
}
function isCharacterData(node:Node|null|undefined):node is CharacterData {
  return !!node && (node.nodeType === Node.TEXT_NODE || node.nodeType === Node.CDATA_SECTION_NODE);
}

/* eslint-disable no-underscore-dangle */
import React from 'react';
import ReactDOM from 'react-dom/client';

interface Options {
  shadow?:boolean;
  /** How to treat initial light DOM children. */
  contentStrategy?:'snapshot' | 'remove' | 'slot';
  /** Optional defer strategy for first render to allow frameworks to bind children. */
  initialRenderDelayMs?:number; // default 0; if children empty, wait rAF
  /** CSS to inject into the shadow root (strings or constructed stylesheets). */
  adoptStyles?:(string | CSSStyleSheet)[];
  /** Copy CSS rules from document.styleSheets that match these patterns. */
  adoptMatchingStyles?:{
    /** Match by selector substring or regex against CSSStyleRule.selectorText. */
    selectors?:(string | RegExp)[];
    /** Optional regex to match raw rule cssText. */
    text?:RegExp;
  };
  /** Named slots to create (used only with shadow:true + contentStrategy:'slot'). */
  slots?:string[];
  /** Build React children from named/default slots. */
  childrenFromSlots?:(helpers:{
    assigned:(name?:string) => Node[];
    reactNodes:(name?:string) => React.ReactNode[];
  }) => React.ReactNode | React.ReactNode[];
  /** Explicit list of attributes to observe; defaults to all initial attributes. */
  attributes?:string[];
  /** Event prop name -> custom event name mapping (e.g. { onClick: 'click' }). */
  events?:Record<string, string>;
  /** Optional mapping function from attribute name to prop name. */
  mapAttributeToProp?:(attr:string) => string;
  /** Derive additional React props from the host element on each render/attribute change. */
  deriveProps?:(host:HTMLElement) => Record<string, unknown>;
}

/**
 * Wrap a React component to register as a Web Component.
 */
export function defineReactElement<Props extends object = object>(
  tagName:string,
  ReactComponent:React.ComponentType<Props>,
  options:Options = {},
) {
  const useShadow = options.shadow ?? true;
  const requestedStrategy = options.contentStrategy ?? 'snapshot';
  const effectiveStrategy:'snapshot' | 'remove' | 'slot' =
    requestedStrategy === 'slot' && !useShadow ? 'snapshot' : requestedStrategy;
  const mapAttributeToProp =
    options.mapAttributeToProp ??
    ((attr:string) => {
      // Preserve aria-* and data-* exactly so React receives correct accessibility/data attributes
      if (attr.startsWith('aria-') || attr.startsWith('data-')) return attr;
      // Map HTML class -> React className
      if (attr === 'class') return 'className';
      return attr
        .split('-')
        .map((p, i) => (i === 0 ? p : p.charAt(0).toUpperCase() + p.slice(1)))
        .join('');
    });

  class ReactElement extends HTMLElement {
    private _root:ReactElement | ShadowRoot;
    private _reactRoot?:ReactDOM.Root;
    private _props:Props = {} as Props;
    private _staticReactChildren:React.ReactNode[] = [];
    private _mountContainer:HTMLElement | null = null;
    private _slotEl?:HTMLSlotElement;
    private _namedSlots:Record<string, HTMLSlotElement> = {};
    private _fallbackWrapper?:HTMLElement;
    private _observer?:MutationObserver;
    private _renderScheduled = false;
    private _initialRendered = false;

    constructor() {
      super();
      this._root = useShadow ? this.attachShadow({ mode: 'open' }) : this;
      // Do not snapshot here; Angular may bind children after creation.
    }

    static get observedAttributes():string[] {
      if (options.attributes?.length) return options.attributes;
      // default: all attributes present at construction time
      return [];
    }

    connectedCallback() {
      // Adopt styles into shadow root if requested
      if (useShadow && options.adoptStyles && this._root instanceof ShadowRoot) {
        this._adoptStyles(this._root, options.adoptStyles);
      }
      if (useShadow && options.adoptMatchingStyles && this._root instanceof ShadowRoot) {
        this._adoptMatchingStyles(this._root, options.adoptMatchingStyles);
      }
      // Kick initial render when children are ready or after a small delay
      this._ensureInitialRender();
      // If slot strategy with shadow root, insert slots for native projection
      if (effectiveStrategy === 'slot' && useShadow) {
        if (!this._slotEl) {
          this._slotEl = document.createElement('slot');
          this._root.appendChild(this._slotEl);
          this._slotEl.addEventListener('slotchange', () => this._scheduleRender());
        }
        if (options.slots) {
          for (const name of options.slots) {
            if (!this._namedSlots[name]) {
              const s = document.createElement('slot');
              s.name = name;
              s.addEventListener('slotchange', () => this._scheduleRender());
              this._namedSlots[name] = s;
              this._root.appendChild(s);
            }
          }
        }
      }

      // Create inner mount container (always) so we have a stable React root
      if (!this._mountContainer) {
        this._mountContainer = document.createElement('span');
        this._mountContainer.setAttribute('data-react-root', '');
        this._root.appendChild(this._mountContainer);
      }

      // If using snapshot in light DOM, wrap original children and hide them to avoid duplicate rendering
      if (effectiveStrategy === 'snapshot' && !useShadow && !this._fallbackWrapper) {
        this._fallbackWrapper = document.createElement('span');
        this._fallbackWrapper.dataset.fallback = '';
        this._fallbackWrapper.setAttribute('aria-hidden', 'true');
        this._fallbackWrapper.setAttribute('inert', '');
        this._fallbackWrapper.hidden = true;
        this._root.insertBefore(this._fallbackWrapper, this._mountContainer);
        // Move all existing light DOM nodes except the mount container into the wrapper
        for (const n of Array.from(this.childNodes)) {
          if (n !== this._mountContainer) {
            this._fallbackWrapper.appendChild(n);
          }
        }
      }

      // Determine children according to strategy
      let children:React.ReactNode[];
      if (effectiveStrategy === 'slot') {
        if (useShadow) {
          // If provided, use custom builder to compose children from slots
          if (options.childrenFromSlots) {
            const built = options.childrenFromSlots({
              assigned: (name?:string) => this._assignedNodes(name),
              reactNodes: (name?:string) => this._reactNodesFromAssigned(name),
            });
            children = Array.isArray(built) ? built : [built];
          } else {
            children = this._getSlottedReactChildren();
          }
          // Hide all slots to avoid duplicate rendering
          if (this._slotEl) {
            this._slotEl.hidden = true;
            this._slotEl.setAttribute('aria-hidden', 'true');
            this._slotEl.setAttribute('inert', '');
          }
          for (const s of Object.values(this._namedSlots)) {
            s.hidden = true;
            s.setAttribute('aria-hidden', 'true');
            s.setAttribute('inert', '');
          }
        } else {
          // Should not be reached because effectiveStrategy already normalized, but keep as safety
          children = this._childrenFromCurrent();
        }
      } else if (effectiveStrategy === 'remove') {
        // Build static children from current nodes then clear DOM
        if (this._staticReactChildren.length === 0) {
          this._staticReactChildren = this._childrenFromCurrent();
        }
        children = this._staticReactChildren;
        // Clear original light DOM (except mount container if added later)
        const nodes = this._currentNodes();
        for (const node of nodes) {
          if (node.parentNode) node.parentNode.removeChild(node);
        }
      } else {
        children = this._childrenFromCurrent();
      }

      // Initial attribute -> prop mapping
      for (const { name, value } of Array.from(this.attributes)) {
        const propName = mapAttributeToProp(name) as keyof Props;
        (this._props as unknown as Record<string, unknown>)[propName as string] = value as unknown;
      }

      // Allow caller to derive additional props (e.g., map attributes to complex props)
      if (options.deriveProps) {
        Object.assign(this._props as unknown as Record<string, unknown>, options.deriveProps(this));
      }

      // Inject event forwarding callbacks
      if (options.events) {
        for (const [propName, eventName] of Object.entries(options.events)) {
          (this._props as unknown as Record<string, unknown>)[propName] = ((...detail:unknown[]) => {
            this.dispatchEvent(new CustomEvent(eventName, { detail }));
          }) as unknown;
        }
      }

      const props = this._props;

      this._reactRoot = ReactDOM.createRoot(this._mountContainer);
      this._reactRoot.render(React.createElement(ReactComponent, props, ...children));

      // Observe light DOM changes (only meaningful without shadow root and snapshot strategy)
      if (effectiveStrategy === 'snapshot' && !useShadow && !this._observer) {
        this._observer = new MutationObserver((mutations) => {
          let relevant = false;
          for (const m of mutations) {
            if (m.type === 'childList' || m.type === 'characterData') {
              relevant = true;
              break;
            }
          }
          if (relevant) {
            this._scheduleRender();
          }
        });
        const target:Node = this._fallbackWrapper ?? this;
        this._observer.observe(target, { childList: true, characterData: true, subtree: true });
      }

      // Ensure an initial render even if Angular binds children later (next microtask)
      this._scheduleRender();
    }

    private _ensureInitialRender() {
      if (this._initialRendered) return;
      const delayMs = options.initialRenderDelayMs ?? 0;
      const tryRender = () => {
        if (this._initialRendered) return;
        const hasChildren =
          (effectiveStrategy === 'slot' &&
            useShadow &&
            this._slotEl &&
            this._slotEl.assignedNodes({ flatten: true }).length > 0) ??
          (effectiveStrategy !== 'slot' && this._currentNodes().length > 0);
        if (hasChildren) {
          this._initialRendered = true;
          this._renderNow();
        } else {
          // Wait one animation frame then render anyway to avoid blank UI
          requestAnimationFrame(() => {
            if (!this._initialRendered) {
              this._initialRendered = true;
              this._renderNow();
            }
          });
        }
      };
      if (delayMs > 0) {
        setTimeout(tryRender, delayMs);
      } else {
        // If slot strategy, slotchange will also trigger; but we still attempt here
        tryRender();
      }
    }

    attributeChangedCallback(name:string, _oldValue:string | null, newValue:string | null) {
      const propName = mapAttributeToProp(name) as keyof Props;
      if (newValue === null) {
        delete (this._props as unknown as Record<string, unknown>)[propName as string];
      } else {
        (this._props as unknown as Record<string, unknown>)[propName as string] = newValue as unknown;
      }
      if (options.deriveProps) {
        Object.assign(this._props as unknown as Record<string, unknown>, options.deriveProps(this));
      }
      if (this._reactRoot) {
        this._renderNow();
      }
    }

    private _scheduleRender() {
      if (this._renderScheduled) return;
      this._renderScheduled = true;
      queueMicrotask(() => {
        this._renderScheduled = false;
        this._renderNow();
      });
    }

    private _renderNow() {
      if (!this._reactRoot) return;
      let reactChildren:React.ReactNode[];
      if (effectiveStrategy === 'slot' && useShadow) {
        if (options.childrenFromSlots) {
          const built = options.childrenFromSlots({
            assigned: (name?:string) => this._assignedNodes(name),
            reactNodes: (name?:string) => this._reactNodesFromAssigned(name),
          });
          reactChildren = Array.isArray(built) ? built : [built];
        } else {
          reactChildren = this._getSlottedReactChildren();
        }
      } else if (effectiveStrategy === 'remove') {
        reactChildren = this._staticReactChildren;
      } else {
        reactChildren = this._childrenFromCurrent();
      }
      this._reactRoot.render(React.createElement(ReactComponent, this._props, ...reactChildren));
    }

    private _currentNodes():Node[] {
      if (effectiveStrategy === 'slot' && useShadow && this._slotEl) {
        return Array.from(this._slotEl.assignedNodes({ flatten: true }));
      }
      if (this._fallbackWrapper) return Array.from(this._fallbackWrapper.childNodes);
      return Array.from(this.childNodes).filter((n) => n !== this._mountContainer);
    }

    private _childrenFromCurrent():React.ReactNode[] {
      const nodes = this._currentNodes();
      return nodes.map((node, i) => {
        if (node.nodeType === Node.TEXT_NODE) return node.textContent;
        return React.createElement(
          'span',
          { key: i },
          React.createElement((node as Element).tagName.toLowerCase(), {}),
        );
      });
    }

    private _getSlottedReactChildren():React.ReactNode[] {
      if (!this._slotEl) return [];
      const assigned = this._slotEl.assignedNodes({ flatten: true });
      return assigned.map((node, i) => {
        if (node.nodeType === Node.TEXT_NODE) return node.textContent;
        return React.createElement(
          'span',
          { key: i },
          React.createElement((node as Element).tagName.toLowerCase(), {}),
        );
      });
    }

    private _assignedNodes(name?:string):Node[] {
      if (!name) return this._slotEl ? Array.from(this._slotEl.assignedNodes({ flatten: true })) : [];
      const s = this._namedSlots[name];
      return s ? Array.from(s.assignedNodes({ flatten: true })) : [];
    }

    private _reactNodesFromAssigned(name?:string):React.ReactNode[] {
      const assigned = this._assignedNodes(name);
      return assigned.map((node, i) => {
        if (node.nodeType === Node.TEXT_NODE) return node.textContent;
        return React.createElement(
          'span',
          { key: i },
          React.createElement((node as Element).tagName.toLowerCase(), {}),
        );
      });
    }

    disconnectedCallback() {
      this._reactRoot?.unmount();
      this._observer?.disconnect();
    }

    private _adoptStyles(root:ShadowRoot, styles:(string | CSSStyleSheet)[]) {
      const sheets:CSSStyleSheet[] = [];
      for (const s of styles) {
        if (typeof s === 'string') {
          const styleEl = document.createElement('style');
          styleEl.textContent = s;
          root.appendChild(styleEl);
        } else if (s) {
          sheets.push(s);
        }
      }
      try {
        // Only attempt if supported and there are sheets to adopt
        if (sheets.length && 'adoptedStyleSheets' in root) {
          const r = root as unknown as { adoptedStyleSheets?:CSSStyleSheet[] };
          const current = r.adoptedStyleSheets;
          r.adoptedStyleSheets = [...(current ?? []), ...sheets];
        } else {
          // Fallback: serialize CSSStyleSheet rules into <style>
          for (const sh of sheets) {
            try {
              const styleEl = document.createElement('style');
              const cssText = Array.from(sh.cssRules ?? [])
                .map((r) => r.cssText)
                .join('\n');
              styleEl.textContent = cssText;
              root.appendChild(styleEl);
            } catch {
              // Cross-origin or unreadable stylesheet; skip silently
            }
          }
        }
      } catch {
        // Ignore adoption failures
      }
    }

    private _adoptMatchingStyles(root:ShadowRoot, cfg:{ selectors?:(string | RegExp)[]; text?:RegExp }) {
      const chunks:string[] = [];
      const matchSelector = (sel:string):boolean => {
        if (!cfg.selectors || cfg.selectors.length === 0) return false;
        return cfg.selectors.some((p) => (typeof p === 'string' ? sel.includes(p) : p.test(sel)));
      };
      const serializeRule = (rule:CSSRule):string | null => {
        try {
          if ((rule as CSSStyleRule).selectorText !== undefined) {
            const styleRule = rule as CSSStyleRule;
            if (cfg.text?.test(styleRule.cssText) || matchSelector(styleRule.selectorText)) {
              return styleRule.cssText;
            }
            return null;
          }
          if ((rule as CSSMediaRule).media !== undefined) {
            const media = rule as CSSMediaRule;
            const inner:string[] = [];
            for (const r of Array.from(media.cssRules || [])) {
              const s = serializeRule(r);
              if (s) inner.push(s);
            }
            return inner.length ? `@media ${media.media.mediaText}{${inner.join('\n')}}` : null;
          }
          if ((rule as CSSSupportsRule).conditionText !== undefined) {
            const supports = rule as CSSSupportsRule;
            const inner:string[] = [];
            for (const r of Array.from(supports.cssRules || [])) {
              const s = serializeRule(r);
              if (s) inner.push(s);
            }
            return inner.length ? `@supports ${supports.conditionText}{${inner.join('\n')}}` : null;
          }
        } catch {
          return null;
        }
        return null;
      };
      for (const sheet of Array.from(document.styleSheets)) {
        let rules:CSSRuleList | undefined;
        try {
          // Access may throw on cross-origin sheets
          rules = sheet.cssRules;
        } catch {
          continue;
        }
        if (!rules) continue;
        for (const rule of Array.from(rules)) {
          const s = serializeRule(rule);
          if (s) chunks.push(s);
        }
      }
      if (chunks.length) {
        const styleEl = document.createElement('style');
        styleEl.textContent = chunks.join('\n');
        root.appendChild(styleEl);
      }
    }
  }

  customElements.define(tagName, ReactElement);
}

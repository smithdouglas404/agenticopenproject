import { ActionMenu, Button, ActionList, IconButton } from '@primer/react';
import { PencilIcon, PlusIcon, GrabberIcon, UndoIcon, XIcon } from '@primer/octicons-react';

import { defineReactElement } from './wrap-react';
import React from 'react';

defineReactElement('primer-grabber-icon', GrabberIcon, {
  attributes: ['size'],
  events: { onClick: 'click' },
  shadow: false,
  contentStrategy: 'remove',
  deriveProps: (host):Partial<React.ComponentProps<typeof GrabberIcon>> => {
    const props:Partial<React.ComponentProps<typeof GrabberIcon>> = {};
    const klass = host.getAttribute('class');
    props.className = klass ?? props.className;
    return props;
  },
});

defineReactElement('primer-icon-button', IconButton, {
  attributes: ['variant', 'icon', 'icon-size', 'aria-label', 'size'],
  events: { onClick: 'click' },
  shadow: true,
  contentStrategy: 'slot',
  adoptStyles: [
    `:host{display:inline-block}
		 button{appearance:none;-webkit-appearance:none;display:inline-flex;align-items:center;justify-content:center;
			 font:inherit;line-height:1;cursor:pointer;border-radius:6px;border:1px solid var(--borderColor-default,#d0d7de);
			 background:var(--button-default-bg,#f6f8fa);color:var(--fgColor-default,#24292f);padding:0.4rem;aspect-ratio:1/1;}
		 button:hover{background:var(--button-hover-bg,#eef1f4)}
		 button:active{background:var(--button-active-bg,#e7ebef)}
		 button:focus{outline:2px solid var(--focus-outline,#0969da);outline-offset:2px}
		 button[disabled]{cursor:not-allowed;opacity:.6}`,
  ],
  adoptMatchingStyles: {
    // Copy any stylesheet rules that reference Primer compiled classes (prc- prefix) or IconButton naming
    selectors: [/\.prc-/, /IconButton/],
  },
  initialRenderDelayMs: 16,
  deriveProps: (host):Partial<React.ComponentProps<typeof IconButton>> => {
    const props:Partial<React.ComponentProps<typeof IconButton>> = {};
    const iconName = host.getAttribute('icon');
    const iconSizeAttr = host.getAttribute('icon-size');
    const sizeAttr = host.getAttribute('size');
    if (sizeAttr) props.size = sizeAttr as React.ComponentProps<typeof IconButton>['size'];
    const iconMap:Record<string, React.ComponentType<{ size?:number }>> = {
      plus: PlusIcon,
      pencil: PencilIcon,
      undo: UndoIcon,
      x: XIcon,
    };
    const resolveIcon = (
      name:string | null,
      sizeVal:string | null,
    ):React.ComponentType<{ size?:number }> | (() => React.ReactElement) | undefined => {
      if (!name) return undefined;
      const Icon = iconMap[name.toLowerCase()];
      if (!Icon) return undefined;
      if (sizeVal) {
        const parsed = parseInt(sizeVal, 10);
        if (!Number.isNaN(parsed)) return () => React.createElement(Icon, { size: parsed });
      }
      return Icon;
    };
    // IconButton expects `icon` prop; prefer explicit icon attribute
    const iconVisual = resolveIcon(iconName, iconSizeAttr);
    if (iconVisual) props.icon = iconVisual as React.ComponentProps<typeof IconButton>['icon'];

    const klass = host.getAttribute('class');
    props.className = klass ?? props.className;
    return props;
  },
});

defineReactElement('primer-button', Button, {
  attributes: ['variant', 'leading-icon', 'leading-icon-size'],
  events: { onClick: 'click' },
  shadow: true,
  contentStrategy: 'slot',
  adoptStyles: [
    `:host{display:inline-block}
			button{appearance:none;-webkit-appearance:none;display:inline-flex;align-items:center;justify-content:center;
				font:inherit;line-height:1.25;cursor:pointer;border-radius:6px;border:1px solid var(--borderColor-default,#d0d7de);
				background:var(--button-default-bg,#f6f8fa);color:var(--fgColor-default,#24292f);
				padding:0.4rem 0.65rem;gap:0.4rem;text-decoration:none;}
			button:hover{background:var(--button-hover-bg,#eef1f4)}
			button:active{background:var(--button-active-bg,#e7ebef)}
			button:focus{outline:2px solid var(--focus-outline,#0969da);outline-offset:2px}
			button[aria-busy="true"],button[disabled]{cursor:not-allowed;opacity:.6}`,
  ],
  adoptMatchingStyles: {
    // Copy any stylesheet rules that reference Primer compiled classes (prc- prefix)
    selectors: [/\.prc-/],
  },
  initialRenderDelayMs: 16,
  deriveProps: (host):Partial<React.ComponentProps<typeof Button>> => {
    const props:Partial<React.ComponentProps<typeof Button>> = {};
    const leadingIcon = host.getAttribute('leading-icon');
    const leadingIconSize = host.getAttribute('leading-icon-size');
    const iconMap:Record<string, React.ComponentType<{ size?:number }>> = {
      plus: PlusIcon,
      pencil: PencilIcon,
      undo: UndoIcon,
    };
    if (leadingIcon) {
      const Icon = iconMap[leadingIcon.toLowerCase()];
      if (Icon) {
        const sizeVal = leadingIconSize ? parseInt(leadingIconSize, 10) : undefined;
        props.leadingVisual = sizeVal ? () => React.createElement(Icon, { size: sizeVal }) : Icon;
      }
    }

    const klass = host.getAttribute('class');
    props.className = klass ?? props.className;
    return props;
  },
});

defineReactElement('primer-action-menu', ActionMenu, {
  shadow: true,
  contentStrategy: 'slot',
  slots: ['button', 'overlay'],
  adoptMatchingStyles: {
    selectors: [/\.prc-/],
  },
  initialRenderDelayMs: 16,
  childrenFromSlots: ({ assigned, reactNodes }) => {
    // Button label: if a <button> element was passed, use its text only to avoid <button> inside <button>
    const buttonAssigned = assigned('button');
    let buttonChildren:React.ReactNode[] = [];
    if (
      buttonAssigned.length === 1 &&
      buttonAssigned[0].nodeType === Node.ELEMENT_NODE &&
      (buttonAssigned[0] as Element).tagName.toLowerCase() === 'button'
    ) {
      const label = (buttonAssigned[0] as HTMLElement).textContent ?? '';
      buttonChildren = [label];
    } else {
      buttonChildren = reactNodes('button');
    }

    // Extract button props from the first assigned element attributes (if any)
    const buttonProps:Partial<React.ComponentProps<typeof ActionMenu.Button>> = {};
    if (buttonAssigned[0] && buttonAssigned[0].nodeType === Node.ELEMENT_NODE) {
      const el = buttonAssigned[0] as HTMLElement;
      const variant = el.getAttribute('variant');
      if (variant) buttonProps.variant = variant as React.ComponentProps<typeof ActionMenu.Button>['variant'];
      const leadingIcon = el.getAttribute('leading-icon');
      const leadingIconSize = el.getAttribute('leading-icon-size');
      const iconMap:Record<string, React.ComponentType<{ size?:number }>> = {
        plus: PlusIcon,
      };
      if (leadingIcon) {
        const Icon = iconMap[leadingIcon.toLowerCase()];
        if (Icon) {
          const sizeVal = leadingIconSize ? parseInt(leadingIconSize, 10) : undefined;
          buttonProps.leadingVisual = sizeVal ? () => React.createElement(Icon, { size: sizeVal }) : Icon;
        }
      }
    }
    // Build overlay content: map <primer-action-list> and its items to Primer React <ActionList>
    const overlayAssigned = assigned('overlay');
    let overlayChild:React.ReactNode | undefined;
    const findList = (node:Node):Element | undefined => {
      if (node.nodeType === Node.ELEMENT_NODE) {
        const el = node as Element;
        if (el.tagName.toLowerCase() === 'primer-action-list') return el;
        for (const child of Array.from(el.children)) {
          const found = findList(child);
          if (found) return found;
        }
      }
      return undefined;
    };
    for (const n of overlayAssigned) {
      const listEl = findList(n);
      if (listEl) {
        const items:React.ReactNode[] = [];
        const children = Array.from(listEl.children);
        children.forEach((c, idx) => {
          if (c.tagName.toLowerCase() === 'primer-action-list-item') {
            const label = c.textContent;
            const onClick = () => {
              // Forward click to original slotted element so Angular (click) bindings fire
              try {
                c.dispatchEvent(new MouseEvent('click', { bubbles: true, composed: true }));
              } catch {
                // ignore
              }
            };
            items.push(React.createElement(ActionList.Item, { key: idx, onClick }, label));
          }
        });
        overlayChild = React.createElement(ActionList, null, ...items);
        break;
      }
    }
    // Fallback: pass through raw overlay nodes if no list found
    const overlayChildren = overlayChild ? [overlayChild] : reactNodes('overlay');
    return [
      React.createElement(ActionMenu.Button, buttonProps, ...buttonChildren),
      React.createElement(ActionMenu.Overlay, null, ...overlayChildren),
    ];
  },
});

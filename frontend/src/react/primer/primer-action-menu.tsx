import React from 'react';
import ReactDOM from 'react-dom/client';
import {
  ActionMenu,
  ActionList,
} from '@primer/react'; 
import '@primer/css/dist/primer.css'
import '@primer/primitives/dist/css/functional/themes/light.css'


const isElement = (node:Node):node is Element => node.nodeType === Node.ELEMENT_NODE;

function convertNodesToReact(children:NodeList|Node[]):string|React.ReactNode {
  return Array.from(children).map((node) => {
    if (node.nodeType === Node.TEXT_NODE) {
      return node.textContent;
    }

    if (!isElement(node)) {
      return;
    }

    const slot = (node).getAttribute('slot');

    switch (slot) {
      case 'item':
        return (
          <ActionList.Item onSelect={() => console.log('Item clicked')}>
            {convertNodesToReact(node.childNodes)}
          </ActionList.Item>
        );

      case 'link-item':
        return (
          <ActionList.LinkItem href={node.getAttribute('href') ?? ''}>
            {convertNodesToReact(node.childNodes)}
          </ActionList.LinkItem>
        );

      case 'divider':
        return <ActionList.Divider />;

      case 'group':
        return (
          <ActionList.Group>
            {convertNodesToReact(node.childNodes)}
          </ActionList.Group>
        );

      case 'group-heading':
        return (
          <ActionList.GroupHeading>
            {node.textContent}
          </ActionList.GroupHeading>
        );

      case 'leading-visual':
        return (
          <ActionList.LeadingVisual>
            {convertNodesToReact(node.childNodes)}
          </ActionList.LeadingVisual>
        );

      default:
        return convertNodesToReact(node.childNodes);
    }
  });
}

export function mount(element:Element) {
  const shadowRoot = element.shadowRoot!;
  const root = ReactDOM.createRoot(shadowRoot);

  function update() {
    const buttonSlot = shadowRoot.querySelector<HTMLSlotElement>('slot[name="button"]');
    const overlaySlot = shadowRoot.querySelector<HTMLSlotElement>('slot[name="overlay"]');

    const buttonNodes = buttonSlot?.assignedNodes() ?? [];
    const overlayNodes = overlaySlot?.assignedNodes() ?? [];

    const overlayReact = convertNodesToReact(overlayNodes);

    root.render(
      <ActionMenu>
        <ActionMenu.Button>
          {convertNodesToReact(buttonNodes)}
        </ActionMenu.Button>

        <ActionMenu.Overlay width="auto">
          <ActionList>
            {overlayReact}
          </ActionList>
        </ActionMenu.Overlay>
      </ActionMenu>
    );
  }

  shadowRoot.addEventListener('slotchange', update);
  update();
}

import React from 'react';
import type { Root } from 'react-dom/client';
import { createRoot } from 'react-dom/client';
import { PrimerProviderWrapper } from 'core-react/bridge/primer-provider-wrapper';
import { WpCardBoards } from 'core-react/components/wp-card-boards/WpCardBoards';
import type { WpCardData } from 'core-react/components/wp-card-boards/types';

class WpCardBoardsElement extends HTMLElement {
  private reactRoot:Root | null = null;

  static get observedAttributes() {
    return ['data-wp'];
  }

  connectedCallback() {
    this.reactRoot = createRoot(this);
    this.renderCard();
  }

  disconnectedCallback() {
    if (this.reactRoot) {
      this.reactRoot.unmount();
      this.reactRoot = null;
    }
  }

  attributeChangedCallback() {
    this.renderCard();
  }

  private renderCard() {
    if (!this.reactRoot) return;

    const wpJson = this.getAttribute('data-wp');
    if (!wpJson) return;

    let workPackage:WpCardData;
    try {
      workPackage = JSON.parse(wpJson) as WpCardData;
    } catch (e) {
      console.error('op-wp-card-boards: failed to parse data-wp attribute', e);
      return;
    }

    this.reactRoot.render(
      React.createElement(
        PrimerProviderWrapper,
        null,
        React.createElement(WpCardBoards, {
          workPackage,
          onCardClick: () => {
            this.dispatchEvent(new CustomEvent('card-click', {
              detail: { workPackageId: workPackage.id },
              bubbles: true,
            }));
          },
          onCardDoubleClick: () => {
            this.dispatchEvent(new CustomEvent('card-dblclick', {
              detail: { workPackageId: workPackage.id },
              bubbles: true,
            }));
          },
          onCardContextMenu: (event:React.MouseEvent) => {
            this.dispatchEvent(new CustomEvent('card-contextmenu', {
              detail: { workPackageId: workPackage.id, originalEvent: event.nativeEvent },
              bubbles: true,
            }));
          },
          onMenuClick: (event:React.MouseEvent) => {
            this.dispatchEvent(new CustomEvent('card-menu', {
              detail: { workPackageId: workPackage.id, originalEvent: event.nativeEvent },
              bubbles: true,
            }));
          },
          onIdClick: () => {
            this.dispatchEvent(new CustomEvent('card-id-click', {
              detail: { workPackageId: workPackage.id },
              bubbles: true,
            }));
          },
        }),
      ),
    );
  }
}

if (!customElements.get('op-wp-card-boards')) {
  customElements.define('op-wp-card-boards', WpCardBoardsElement);
}

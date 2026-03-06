import React from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { PrimerProviderWrapper } from './primer-provider-wrapper';

export class ReactBridge {
  static openDialog<TResult>(
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    Component:React.ComponentType<any>,
    props:Record<string, unknown>,
  ):Promise<TResult | null> {
    return new Promise((resolve) => {
      const container = document.createElement('div');
      container.setAttribute('data-react-bridge', 'true');
      document.body.appendChild(container);

      let root:Root | null = null;

      const cleanup = () => {
        if (root) {
          root.unmount();
          root = null;
        }
        container.remove();
      };

      const onSubmit = (result:TResult) => {
        cleanup();
        resolve(result);
      };

      const onCancel = () => {
        cleanup();
        resolve(null);
      };

      root = createRoot(container);
      root.render(
        React.createElement(
          PrimerProviderWrapper,
          null,
          React.createElement(Component, { ...props, onSubmit, onCancel }),
        ),
      );
    });
  }
}

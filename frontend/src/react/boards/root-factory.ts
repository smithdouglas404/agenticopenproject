import { createRoot, type Root } from 'react-dom/client';

export const boardRootFactory = {
  create(container:HTMLElement):Root {
    return createRoot(container);
  },
};

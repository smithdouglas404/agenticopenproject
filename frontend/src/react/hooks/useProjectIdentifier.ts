import { getMetaValue } from 'core-app/core/setup/globals/global-helpers';
import { useSyncExternalStore } from 'react';

export function useProjectIdentifier() {
  return useSyncExternalStore(
    (callback) => {
      const observer = new MutationObserver(callback);
      const meta = document.head.querySelector('meta[name="current_project"]');
      if (meta) {
        observer.observe(meta, { attributes: true });
      }
      return () => observer.disconnect();
    },
    () => getMetaValue('current_project', 'projectIdentifier'),
  );
}

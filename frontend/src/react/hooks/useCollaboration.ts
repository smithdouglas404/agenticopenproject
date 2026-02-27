/*
 * -- copyright
 * OpenProject is an open source project management software.
 * Copyright (C) the OpenProject GmbH
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License version 3.
 *
 * OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
 * Copyright (C) 2006-2013 Jean-Philippe Lang
 * Copyright (C) 2010-2013 the ChiliProject Team
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * See COPYRIGHT and LICENSE files for more details.
 * ++
 */

import { HocuspocusProvider } from '@hocuspocus/provider';
import { debugLog } from 'core-app/shared/helpers/debug_output';
import {
  PROVIDER_AUTH_ERROR_EVENT,
  ProviderAuthErrorKind,
} from 'core-stimulus/services/documents/token-refresh.service';
import { useCallback, useEffect, useRef, useState } from 'react';

const DEFAULT_CONNECTION_TIMEOUT_MS = 5000;

/**
 * Calls `onTimeout` if the provider has not synced within `timeoutMs`.
 * The timer is cancelled proactively when the provider emits 'synced',
 * so it never fires after a successful connection.
 */
function useConnectionTimeout(provider:HocuspocusProvider, onTimeout:() => void, timeoutMs = DEFAULT_CONNECTION_TIMEOUT_MS) {
  const timeoutRef = useRef<ReturnType<typeof setTimeout>|null>(null);

  useEffect(() => {
    if (provider.synced) {
      return;
    }

    const cancel = () => {
      if (timeoutRef.current !== null) {
        clearTimeout(timeoutRef.current);
        timeoutRef.current = null;
      }
    };

    timeoutRef.current = setTimeout(() => {
      timeoutRef.current = null;
      onTimeout();
    }, timeoutMs);

    // Cancel the timer as soon as the provider syncs rather than waiting
    // for the full timeout to elapse.
    provider.on('synced', cancel);

    return () => {
      provider.off('synced', cancel);
      cancel();
    };
  }, [provider, onTimeout, timeoutMs]);
}

/**
 * Subscribes to the provider's 'synced' and 'disconnect' events and
 * forwards them to the supplied callbacks.
 *
 * Listeners are registered before the initial synced check so that a
 * sync event emitted between registration and the check is never lost.
 * If the provider is already synced on mount, `onSynced` is called
 * immediately.
 */
function useCollaborationProvider(
  provider:HocuspocusProvider,
  onSynced:() => void,
  onDisconnect:() => void,
) {
  useEffect(() => {
    provider.on('synced', onSynced);
    provider.on('disconnect', onDisconnect);

    if (provider.synced) {
      onSynced();
    }

    return () => {
      provider.off('synced', onSynced);
      provider.off('disconnect', onDisconnect);
    };
  }, [provider, onSynced, onDisconnect]);
}

/**
 * Tracks the real-time connection state of a HocuspocusProvider and
 * exposes it as React state for the BlockNote editor.
 *
 * Returns:
 * - `isLoading`   — true while waiting for the first sync after mount.
 * - `offlineMode` — true when the connection is lost or timed out;
 *                   the editor remains editable and changes are queued
 *                   locally (IndexedDB) until the server is reachable again.
 *
 * Transitions:
 *   mount → synced           : isLoading false, offlineMode false
 *   mount → timeout (5s)     : isLoading false, offlineMode true
 *   connected → disconnect   : offlineMode true
 *   offline → re-synced      : offlineMode false
 *   any → auth error         : isLoading false, offlineMode true
 */
function useCollaboration(provider:HocuspocusProvider) {
  const [isLoading, setIsLoading] = useState(true);
  const [offlineMode, setOfflineMode] = useState(false);

  const handleSynced = useCallback(() => {
    debugLog('(BlockNote Editor) synced with collaboration server');
    setIsLoading(false);
    setOfflineMode(false); // banner disappears
  }, []);

  const handleDisconnect = useCallback(() => {
    debugLog('(BlockNote Editor) Disconnected - offline mode');
    setIsLoading(false);
    setOfflineMode(true); // show the banner, editing is available
  }, []);

  const handleTimeout = useCallback(() => {
    debugLog('(BlockNote Editor) Connection to collaboration server timed out - now in offline mode');
    setIsLoading(false);
    setOfflineMode(true);
  }, []);

  useConnectionTimeout(provider, handleTimeout);
  useCollaborationProvider(provider, handleSynced, handleDisconnect);

  useEffect(() => {
    const handleProviderAuthError = (event:Event) => {
      const customEvent = event as CustomEvent<{ kind:ProviderAuthErrorKind; message:string }>;
      debugLog(`(BlockNote Editor) Provider auth error: ${customEvent.detail.kind} - ${customEvent.detail.message}`);
      setOfflineMode(true);
      setIsLoading(false);
    };

    document.addEventListener(PROVIDER_AUTH_ERROR_EVENT, handleProviderAuthError);
    return () => document.removeEventListener(PROVIDER_AUTH_ERROR_EVENT, handleProviderAuthError);
  }, []);

  return { isLoading, offlineMode } as const;
}

export { useCollaboration };

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
import { Controller } from '@hotwired/stimulus';
import { LiveCollaborationManager } from 'core-stimulus/helpers/live-collaboration-helpers';
import {
  PROVIDER_AUTH_ERROR_EVENT,
  ProviderAuthErrorKind,
  TokenRefreshService,
} from 'core-stimulus/services/documents/token-refresh.service';
import type { Doc } from 'yjs';
import * as Y from 'yjs';
import { IndexeddbPersistence } from 'y-indexeddb';
import { debugLog } from 'core-app/shared/helpers/debug_output';

const INDEXEDDB_SYNC_TIMEOUT_MS = 10_000;

export default class extends Controller {
  static values = {
    hocuspocusUrl: String,
    tokenPayload: String,
    documentName: String,
    tokenExpiresInSeconds: Number,
    refreshUrl: String,
  };

  declare readonly hocuspocusUrlValue:string;
  declare readonly tokenPayloadValue:string;
  declare readonly documentNameValue:string;
  declare readonly tokenExpiresInSecondsValue:number;
  declare readonly refreshUrlValue:string;

  private tokenRefreshService:TokenRefreshService | null = null;
  private indexeddbPersistence:IndexeddbPersistence | null = null;
  private ownedProvider:HocuspocusProvider | null = null;
  private currentToken = '';
  private canUseCachedToken = true;

  // On initial load, the DOM token is fresh. On reconnection (e.g., after server restart),
  // we must fetch a fresh token since the cached one may be expired.
  private getToken = async ():Promise<string> => {
    if (this.canUseCachedToken) {
      this.canUseCachedToken = false;
      return this.currentToken;
    }
    const data = await TokenRefreshService.fetchToken(this.refreshUrlValue);
    this.currentToken = data.encrypted_token;
    return this.currentToken;
  };

  // Helper function for waiting for IndexedDB synchronization
  private waitForIndexedDBSync = (ydoc:Doc):Promise<void> => {
    const persistence = new IndexeddbPersistence(`op-doc-${this.documentNameValue}`, ydoc);
    this.indexeddbPersistence = persistence;

    // y-indexeddb does not emit an 'error' event, so a timeout is the only
    // protection against hanging indefinitely (e.g. private browsing, quota exceeded)
    let timeoutId:ReturnType<typeof window.setTimeout> | undefined;
    const timeout = new Promise<never>((_, reject) => {
      timeoutId = window.setTimeout(
        () => reject(new Error('IndexedDB sync timed out')),
        INDEXEDDB_SYNC_TIMEOUT_MS,
      );
    });

    return Promise.race([
      persistence.whenSynced.then(() => {
        window.clearTimeout(timeoutId);
        debugLog('(BlockNote Editor) Local document synced via IndexedDB');
      }),
      timeout,
    ]);
  };

  private destroyIndexedDBPersistence():void {
    void this.indexeddbPersistence?.destroy();
    this.indexeddbPersistence = null;
  }

  private async setupProvider():Promise<void> {
    // Clean up any prior incomplete setup to prevent leaking persistence
    // instances on concurrent connect() invocations (e.g., rapid Turbo navigation)
    this.destroyIndexedDBPersistence();

    this.currentToken = this.tokenPayloadValue;

    const ydoc:Doc = new Y.Doc();

    // Waiting for the synchronization of the local copy of IndexedDB
    try {
      await this.waitForIndexedDBSync(ydoc);
    } catch (error) {
      // IndexedDB unavailable or timed out — destroy the partial instance and
      // continue without offline persistence so the editor still renders.
      debugLog(
        '(BlockNote Editor) Failed to sync IndexedDB persistence, continuing without offline persistence',
        error,
      );
      this.destroyIndexedDBPersistence();
    }

    // Detect whether IndexedDB contained cached content for this document.
    // A non-trivial state vector (> 1 byte) means the Y.Doc has real operations from a previous session.
    const hasLocalCache = Y.encodeStateVector(ydoc).byteLength > 1;
    LiveCollaborationManager.setHasLocalCache(hasLocalCache);

    // If disconnect() was called during the IndexedDB await (e.g., Turbo navigation),
    // abort to avoid overwriting the active provider on the new page.
    if (!this.element.isConnected) {
      this.destroyIndexedDBPersistence();
      ydoc.destroy();
      return;
    }

    // Connecting the Hocuspocus Provider after the local data has been loaded
    const provider = new HocuspocusProvider({
      url: this.hocuspocusUrlValue,
      name: this.documentNameValue,
      token: this.getToken,
      document: ydoc,
      onAuthenticationFailed:() => {
        document.dispatchEvent(
          new CustomEvent(PROVIDER_AUTH_ERROR_EVENT, {
            detail: { kind:'authentication' as ProviderAuthErrorKind, message:'Authentication failed' },
          }),
        );
      },
    });

    LiveCollaborationManager.initializeYjsProvider(provider, ydoc);
    this.ownedProvider = provider;

    if (this.refreshUrlValue && this.tokenExpiresInSecondsValue) {
      // Destroy any existing service to prevent duplicate timers if connect() is called multiple times
      this.tokenRefreshService?.destroy();
      this.tokenRefreshService = new TokenRefreshService(provider, this.refreshUrlValue, (newToken) => {
        this.currentToken = newToken;
        this.canUseCachedToken = true;
      });
      this.tokenRefreshService.scheduleRefresh(this.tokenExpiresInSecondsValue);
    }
  }

  connect():void {
    this.setupProvider().catch((error) => {
      debugLog('(BlockNote Editor) Failed to initialize Yjs provider', error);
    });
  }

  disconnect():void {
    this.tokenRefreshService?.destroy();
    this.tokenRefreshService = null;

    this.destroyIndexedDBPersistence();

    // Only destroy if we still own the active provider. During Turbo navigation,
    // a new controller may have already replaced it — see destroyIfOwner().
    if (this.ownedProvider) {
      LiveCollaborationManager.destroyIfOwner(this.ownedProvider);
      this.ownedProvider = null;
    }
  }
}

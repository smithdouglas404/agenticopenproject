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

import type { HocuspocusProvider } from '@hocuspocus/provider';
import { getMetaContent } from 'core-app/core/setup/globals/global-helpers';

export interface TokenResponse {
  encrypted_token:string;
  expires_at:string;
  expires_in_seconds:number;
}

const REFRESH_THRESHOLD = 0.8; // 80% of the token lifetime
const RETRY_DELAY_MS = 5000; // 5 seconds

/**
 * Manages OAuth token refresh for Hocuspocus collaborative editing sessions.
 *
 * Proactively refreshes tokens at 80% of lifetime using session auth,
 * then sends new token to Hocuspocus server via stateless channel.
 *
 * ```
 * Client                              OpenProject                         Hocuspocus
 *   │  [80% of token TTL]                  │                                   │
 *   │── POST /documents/{id}/oauth/refresh_token ──►│                          │
 *   │◄─────────────── {encrypted_token} ───│                                   │
 *   │── REFRESH:<token> ───────────────────┼──────────────────────────────────►│ updates context.token
 *   │  [schedule next refresh]             │                                   │
 * ```
 */
export class TokenRefreshService {
  private refreshTimer:ReturnType<typeof setTimeout> | null = null;
  private provider:HocuspocusProvider;
  private refreshUrl:string;
  private destroyed = false;

  constructor(provider:HocuspocusProvider, refreshUrl:string) {
    this.provider = provider;
    this.refreshUrl = refreshUrl;
  }

  scheduleRefresh(expiresInSeconds:number):void {
    this.clearTimer();

    if (this.destroyed) {
      return;
    }

    const refreshDelayMs = Math.floor(expiresInSeconds * REFRESH_THRESHOLD * 1000);

    this.refreshTimer = setTimeout(() => {
      void this.performRefresh();
    }, refreshDelayMs);
  }

  static async fetchToken(refreshUrl:string):Promise<TokenResponse> {
    const response = await fetch(refreshUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': getMetaContent('csrf-token'),
        'X-Authentication-Scheme': 'Session',
      },
      credentials: 'same-origin',
    });

    if (response.status === 401 || response.status === 403) {
      throw new Error('Session expired');
    }

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    return response.json() as Promise<TokenResponse>;
  }

  async performRefresh():Promise<void> {
    if (this.destroyed) {
      return;
    }

    try {
      const data = await TokenRefreshService.fetchToken(this.refreshUrl);

      this.sendTokenToServer(data.encrypted_token);
      this.scheduleRefresh(data.expires_in_seconds);
    } catch (error) {
      if (error instanceof Error && error.message === 'Session expired') {
        console.warn('[TokenRefresh] Session expired, stopping refresh');
        return;
      }
      console.error('[TokenRefresh] Refresh failed, retrying...', error);
      this.scheduleRetry();
    }
  }

  destroy():void {
    this.destroyed = true;
    this.clearTimer();
  }

  private sendTokenToServer(encryptedToken:string):void {
    this.provider.sendStateless(`REFRESH:${encryptedToken}`);
  }

  private scheduleRetry():void {
    this.clearTimer();

    if (this.destroyed) {
      return;
    }

    this.refreshTimer = setTimeout(() => {
      void this.performRefresh();
    }, RETRY_DELAY_MS);
  }

  private clearTimer():void {
    if (this.refreshTimer !== null) {
      clearTimeout(this.refreshTimer);
      this.refreshTimer = null;
    }
  }
}

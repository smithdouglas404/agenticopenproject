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

import { TurboRequestsService } from 'core-app/core/turbo/turbo-requests.service';
import { useIntersection } from 'stimulus-use';
import BaseController from './base.controller';

/**
 * LazyPageController manages the complete lifecycle of journal pages in the Activities tab.
 *
 * Handles both loading and unloading to implement virtual scrolling:
 * - Loading: Skeleton → Loaded content when entering viewport
 * - Unloading: Loaded content → Skeleton when leaving viewport
 *
 * This unified controller maintains a single IntersectionObserver per page,
 * avoiding the overhead of remounting controllers during load/unload cycles.
 *
 * Virtual scrolling benefits:
 * - Keeps DOM size constant (~5-7 pages) regardless of total activities
 * - Reduces memory usage and improves scroll performance
 * - Seamlessly reloads content when scrolling back to unloaded pages
 */
export default class LazyPageController extends BaseController {
  static values = {
    loadPageUrl: String,
    unloadPageUrl: String,
    page: { type: Number, default: 1 },
    pages: Number,
    isLoaded: { type: Boolean, default: false },
    isUnloadable: { type: Boolean, default: false },
    loadDelayMs: { type: Number, default: 300 },
    unloadDelayMs: { type: Number, default: 3000 },
  };

  declare loadPageUrlValue:string;
  declare unloadPageUrlValue:string;
  declare pageValue:number;
  declare pagesValue:number;
  declare isLoadedValue:boolean;
  declare isUnloadableValue:boolean;
  declare loadDelayMsValue:number;
  declare unloadDelayMsValue:number;

  private turboRequests:TurboRequestsService;
  private stopObserving?:() => void;
  private loadTimeout?:number;
  private unloadTimeout?:number;

  connect() {
    super.connect();
    void this.initializeTurboRequestService();
    this.startObserving();
  }

  disconnect() {
    super.disconnect();
    this.cancelPendingLoad();
    this.cancelPendingUnload();
    this.stopObserving?.();
  }

  appear() {
    // Always cancel pending unload when page comes into view
    this.cancelPendingUnload();

    // If not loaded yet, schedule loading
    if (this.isLoadable) {
      this.scheduleLoad();
    }
  }

  disappear() {
    // Cancel pending load if element leaves viewport before delay expires
    this.cancelPendingLoad();

    // If loaded and unloadable, schedule unloading
    if (this.isLoadedValue && this.isUnloadable) {
      this.scheduleUnload();
    }
  }

  private scheduleLoad() {
    // Delay loading to allow rapid scrolling without triggering loads
    this.loadTimeout = window.setTimeout(() => {
      void this.fetchPageStream()
        .catch((error) => {
          console.error('Error fetching page:', error);
        })
        .finally(() => {
          this.isLoadedValue = true;
        });
    }, this.loadDelayMsValue);
  }

  private scheduleUnload() {
    // Delay unloading to avoid thrashing during rapid scrolling
    this.unloadTimeout = window.setTimeout(() => {
      this.unloadContent();
    }, this.unloadDelayMsValue);
  }

  private startObserving(root = this.scrollableContainer) {
    const [_observe, unobserve] = useIntersection(this, {
      root,
      threshold: 0.05,
      dispatchEvent: false,
    });

    this.stopObserving = unobserve;
  }

  private fetchPageStream():Promise<{ html:string, headers:Headers }> {
    const url = this.prepareRequestUrl(this.loadPageUrlValue);
    return this.turboRequests.requestStream(url);
  }

  private unloadContent() {
    // Request Turbo Stream to replace loaded content with skeleton
    const url = this.prepareRequestUrl(this.unloadPageUrlValue);
    void this.turboRequests.requestStream(url);
  }

  private prepareRequestUrl(requestUrl:string) {
    const baseUrl = window.location.origin;
    const url = new URL(requestUrl, baseUrl);

    url.searchParams.set('filter', this.indexOutlet.filterValue);
    url.searchParams.set('pages', this.pagesValue.toString());
    url.searchParams.set('page', this.pageValue.toString());

    return url.toString();
  }

  private async initializeTurboRequestService() {
    const context = await window.OpenProject.getPluginContext();
    this.turboRequests = context.services.turboRequests;
  }

  private cancelPendingLoad() {
    if (this.loadTimeout) {
      window.clearTimeout(this.loadTimeout);
      this.loadTimeout = undefined;
    }
  }

  private cancelPendingUnload() {
    if (this.unloadTimeout) {
      window.clearTimeout(this.unloadTimeout);
      this.unloadTimeout = undefined;
    }
  }

  private get isLoadable() {
    return !this.isLoadedValue && this.pageValue;
  }

  private get isUnloadable() {
    return this.isUnloadableValue && this.pageValue && this.pageValue > 1;
  }
}

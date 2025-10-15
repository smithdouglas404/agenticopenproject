/*

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
 * UnloadablePageController manages unloading of loaded journal pages to optimize DOM size.
 *
 * When a loaded page exits the viewport for a specified duration:
 * - Replaces heavy journal DOM with lightweight skeleton (LazyPageComponent)
 * - The skeleton has lazy-page controller attached, which will reload on appear
 *
 */
export default class UnloadablePageController extends BaseController {
  static values = {
    url: String,
    page: Number,
    unloadDelayMs: { type: Number, default: 3000 }, // Wait 3s after leaving viewport
    isUnloadable: { type: Boolean, default: false },
  };

  declare urlValue:string;
  declare pageValue:number;
  declare unloadDelayMsValue:number;
  declare isUnloadableValue:boolean;

  private turboRequests:TurboRequestsService;
  private stopObserving?:() => void;
  private unloadTimeout?:number;

  connect() {
    if (!this.isUnloadable) return;

    super.connect();
    void this.initializeTurboRequestService();
    this.startObserving();
  }

  disconnect() {
    super.disconnect();
    this.cancelPendingUnload();
    this.stopObserving?.();
  }

  appear() {
    // Cancel pending unload when page comes back into view
    this.cancelPendingUnload();
  }

  disappear() {
    if (!this.isUnloadable) return;

    // Delay unloading to avoid thrashing during rapid scrolling
    this.unloadTimeout = window.setTimeout(() => {
      this.unloadContent();
    }, this.unloadDelayMsValue);
  }

  private startObserving(root = this.scrollableContainer) {
    if (!root) return;

    const [_observe, unobserve] = useIntersection(this, {
      root,
      threshold: 0,
      // Shrink the viewport by 100% on all sides to create a smaller "keep-alive zone"
      // Pages outside the visible viewport (plus small buffer) will be unloaded
      // This means: keep current viewport + small buffer above/below
      rootMargin: '-100% 0px -100% 0px',
      dispatchEvent: false
    });

    this.stopObserving = unobserve;
  }

  private unloadContent() {
    // Request Turbo Stream to replace loaded content with skeleton
    // The skeleton (LazyPageComponent) has lazy-page controller which handles reloading
    const url = this.prepareUnloadUrl();
    void this.turboRequests.requestStream(url);
  }

  private prepareUnloadUrl():string {
    const baseUrl = window.location.origin;
    const url = new URL(this.urlValue, baseUrl);

    url.searchParams.set('page', this.pageValue.toString());

    return url.toString();
  }

  private async initializeTurboRequestService() {
    const context = await window.OpenProject.getPluginContext();
    this.turboRequests = context.services.turboRequests;
  }

  private cancelPendingUnload() {
    if (this.unloadTimeout) {
      window.clearTimeout(this.unloadTimeout);
      this.unloadTimeout = undefined;
    }
  }

  private get isUnloadable() {
    return this.isUnloadableValue && this.pageValue && this.pageValue > 1;
  }
}

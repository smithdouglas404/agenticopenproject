/*
 * -- copyright
 * OpenProject is an open source project management software.
 * Copyright (C) 2023 the OpenProject GmbH
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

interface QueuedLoad {
  controller:unknown;
  load:() => Promise<void>;
}

/* eslint-disable no-unused-vars */
export interface LazyLoadQueueServiceInterface {
  enqueue(controller:unknown, loadFn:() => Promise<void>):void;
  dequeue(controller:unknown):void;
  clear():void;
}
/* eslint-enable no-unused-vars */

/**
 * Service to manage lazy loading of paginated content with request queuing
 * to prevent simultaneous request storms.
 *
 * Features:
 * - FIFO queue with configurable concurrency limit
 * - Prevents duplicate requests from same controller
 * - Automatic processing when capacity available
 */
export class LazyLoadQueueService implements LazyLoadQueueServiceInterface {
  private queue:QueuedLoad[] = [];
  private activeRequests = 0;
  private maxConcurrentRequests:number;

  constructor(
    maxConcurrentRequests = 2,
  ) {
    this.maxConcurrentRequests = maxConcurrentRequests;
  }

  /**
   * Add a load request to the queue
   * @param controller - The controller instance requesting the load (used for deduplication)
   * @param loadFn - The async function to execute when ready
   */
  enqueue(controller:unknown, loadFn:() => Promise<void>):void {
    // Don't queue if already present (prevent duplicates)
    if (this.queue.some((item) => item.controller === controller)) {
      return;
    }

    this.queue.push({ controller, load: loadFn });
    void this.processQueue();
  }

  /**
   * Remove a load request from the queue
   * @param controller - The controller instance to remove
   */
  dequeue(controller:unknown):void {
    this.queue = this.queue.filter((item) => item.controller !== controller);
  }

  /**
   * Clear all pending requests from the queue
   */
  clear():void {
    this.queue = [];
  }

  private async processQueue():Promise<void> {
    if (this.isAtCapacity || this.isQueueEmpty) return;

    const item = this.queue.shift();
    if (!item) return;

    this.activeRequests += 1;

    try {
      await item.load();
    } catch (error) {
      console.error('Error processing lazy load:', error);
    } finally {
      this.activeRequests -= 1;
      // Process next item in queue
      void this.processQueue();
    }
  }

  private get isAtCapacity():boolean {
    return this.activeRequests >= this.maxConcurrentRequests;
  }

  private get isQueueEmpty():boolean {
    return this.queue.length === 0;
  }
}

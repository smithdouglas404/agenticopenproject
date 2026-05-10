//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import { Controller } from '@hotwired/stimulus';
import { FetchRequest } from '@rails/request.js';
import {
  dropTargetForElements,
  type ElementEventPayloadMap,
  monitorForElements,
} from '@atlaskit/pragmatic-drag-and-drop/element/adapter';
import { extractClosestEdge } from '@atlaskit/pragmatic-drag-and-drop-hitbox/closest-edge';
import { debugLog } from 'core-app/shared/helpers/debug_output';

import {
  buildMoveFormData,
  isItemData,
  resolveFallbackDropTarget,
  resolveListPreviousItemId,
  resolveListTargetId,
  resolvePreviousItemId,
} from './backlogs/drag-and-drop';

type CleanupFn = () => void;
type ElementDropPayload = ElementEventPayloadMap['onDrop'];

export default class BacklogsController extends Controller<HTMLElement> {
  static targets = ['list'];

  declare readonly listTargets:HTMLElement[];

  private cleanupFn?:CleanupFn;
  private listCleanupFns = new Map<HTMLElement, CleanupFn>();
  private abortController:AbortController|null = null;

  connect():void {
    this.abortController = new AbortController();
    this.element.addEventListener('click', this.handleBulkMoveAction, {
      capture: true,
      signal: this.abortController.signal,
    });
    this.cleanupFn = monitorForElements({
      canMonitor: ({ source }) => isItemData(source.data),
      onDrop: (args) => {
        void this.handleDrop(args);
      },
    });
  }

  disconnect():void {
    this.abortController?.abort();
    this.abortController = null;
    this.cleanupFn?.();
    this.cleanupFn = undefined;
    this.listCleanupFns.forEach((cleanup) => cleanup());
    this.listCleanupFns.clear();
  }

  listTargetConnected(element:HTMLElement):void {
    const cleanup = dropTargetForElements({
      element,
      canDrop: ({ source }) => isItemData(source.data),
      getData: () => ({ type: 'list', targetId: resolveListTargetId(element) }),
      getIsSticky: () => false,
    });

    this.listCleanupFns.set(element, cleanup);
  }

  listTargetDisconnected(element:HTMLElement):void {
    this.listCleanupFns.get(element)?.();
    this.listCleanupFns.delete(element);
  }

  private handleBulkMoveAction = (event:MouseEvent):void => {
    const action = this.findBulkMoveAction(event.target);
    if (!action) {
      return;
    }

    const itemId = action.dataset.backlogsBulkItemId;
    const sourceId = action.dataset.backlogsBulkSourceId;
    const url = action.dataset.backlogsBulkUrl;
    const actionType = action.dataset.backlogsBulkAction;
    const selectedItemIds = sourceId ? this.selectedItemIdsFor(sourceId) : [];

    if (!itemId || !sourceId || !url || selectedItemIds.length <= 1 || !selectedItemIds.includes(itemId)) {
      return;
    }

    event.preventDefault();
    event.stopImmediatePropagation();

    if (actionType === 'move-to-sprint') {
      void this.openBulkMoveToSprintDialog({ url, selectedItemIds, sourceId });
    } else {
      const direction = action.dataset.backlogsBulkDirection;
      if (direction) {
        void this.performBulkReorder({ url, selectedItemIds, sourceId, direction });
      }
    }
  };

  private async handleDrop({ location, source }:ElementDropPayload) {
    if (!isItemData(source.data) || !(source.element instanceof HTMLElement)) {
      return;
    }

    const isBulkMove = source.data.itemIds.length > 1;
    const dropUrl = isBulkMove
      ? source.element.getAttribute('data-bulk-drop-url')
      : source.element.getAttribute('data-drop-url');
    if (!dropUrl) {
      return;
    }

    const targetItem = location.current.dropTargets.find(({ data, element }) => (
      isItemData(data) && element instanceof HTMLElement
    ));
    const fallbackTarget = location.current.dropTargets.length === 0
      ? resolveFallbackDropTarget({
        input: location.current.input,
        root: this.element,
        sourceElement: source.element,
        sourceItemIds: source.data.itemIds,
      })
      : null;
    const fallbackItem = fallbackTarget?.isItem ? fallbackTarget : null;
    const resolvedTargetItem = targetItem ?? fallbackItem;
    const targetElement = resolvedTargetItem?.element ?? location.current.dropTargets[0]?.element ?? fallbackTarget?.element;

    if (!(targetElement instanceof HTMLElement)) {
      return;
    }

    const targetId = resolveListTargetId(targetElement);
    if (!targetId) {
      return;
    }

    const previousItemId = resolvedTargetItem?.element instanceof HTMLElement
      ? resolvePreviousItemId({
        sourceItemIds: source.data.itemIds,
        targetItem: resolvedTargetItem.element,
        closestEdge: extractClosestEdge(resolvedTargetItem.data),
      })
      : resolveListPreviousItemId({
        sourceItemIds: source.data.itemIds,
        list: targetElement,
      });

    const request = new FetchRequest(
      'put',
      dropUrl,
      {
        body: buildMoveFormData({
          targetId,
          previousItemId,
          sourceId: isBulkMove ? source.data.sourceId : undefined,
          workPackageIds: isBulkMove ? source.data.itemIds : undefined,
        }),
        responseKind: 'turbo-stream',
      },
    );

    try {
      const response = await request.perform();

      if (!response.ok) {
        debugLog(`Failed to move backlogs item: ${response.statusCode}`);
      }
    } catch (error) {
      debugLog('Failed to move backlogs item due to request error', error);
    }
  }

  private selectedItemIdsFor(sourceId:string):string[] {
    return Array
      .from(this.element.querySelectorAll<HTMLElement>('[data-work-package-card-box-selected="true"]'))
      .filter((item) => item.getAttribute('data-work-package-card-box--item-source-id-value') === sourceId)
      .map((item) => item.dataset.workPackageCardBoxItemId)
      .filter((itemId):itemId is string => !!itemId);
  }

  private findBulkMoveAction(target:EventTarget|null):HTMLElement|null {
    if (!(target instanceof HTMLElement)) {
      return null;
    }

    return target.closest<HTMLElement>('[data-backlogs-bulk-action]');
  }

  private async performBulkReorder({
    url,
    selectedItemIds,
    sourceId,
    direction,
  }:{
    url:string;
    selectedItemIds:string[];
    sourceId:string;
    direction:string;
  }) {
    const body = new FormData();
    body.append('source_id', sourceId);
    body.append('direction', direction);
    selectedItemIds.forEach((itemId) => body.append('work_package_ids[]', itemId));

    await this.performTurboStreamRequest('post', url, body);
  }

  private async openBulkMoveToSprintDialog({
    url,
    selectedItemIds,
    sourceId,
  }:{
    url:string;
    selectedItemIds:string[];
    sourceId:string;
  }) {
    const bulkUrl = new URL(url, window.location.origin);

    bulkUrl.searchParams.set('source_id', sourceId);
    selectedItemIds.forEach((itemId) => bulkUrl.searchParams.append('work_package_ids[]', itemId));

    await this.performTurboStreamRequest('get', bulkUrl.toString());
  }

  private async performTurboStreamRequest(
    method:'get' | 'post' | 'put',
    url:string,
    body?:FormData,
  ) {
    const request = new FetchRequest(method, url, { body, responseKind: 'turbo-stream' });

    try {
      const response = await request.perform();

      if (!response.ok) {
        debugLog(`Failed to perform backlogs bulk move action: ${response.statusCode}`);
      }
    } catch (error) {
      debugLog('Failed to perform backlogs bulk move action due to request error', error);
    }
  }
}

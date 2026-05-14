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

import { Controller } from '@hotwired/stimulus';
import { FetchRequest } from '@rails/request.js';
import { debugLog } from 'core-app/shared/helpers/debug_output';
import { closestInteractiveElement } from 'core-stimulus/helpers/interactive-element-helper';
import invariant from 'tiny-invariant';
import { draggable, dropTargetForElements, monitorForElements } from '@atlaskit/pragmatic-drag-and-drop/element/adapter';
import { combine } from '@atlaskit/pragmatic-drag-and-drop/combine';
import { preventUnhandled } from '@atlaskit/pragmatic-drag-and-drop/prevent-unhandled';
import { attachClosestEdge, extractClosestEdge } from '@atlaskit/pragmatic-drag-and-drop-hitbox/closest-edge';
import { autoScrollForElements } from '@atlaskit/pragmatic-drag-and-drop-auto-scroll/element';
import type { CleanupFn } from '@atlaskit/pragmatic-drag-and-drop/types';

interface TargetConfig {
  container:HTMLElement;
  allowedDragType:string|null;
  targetId:string|null;
}

export default class GenericDragAndDropController extends Controller {
  static targets = ['container', 'item', 'scrollContainer'];

  declare containerTargets:HTMLElement[];
  declare itemTargets:HTMLElement[];
  declare scrollContainerTargets:HTMLElement[];

  static values = {
    handle: { type: Boolean, default: true },
    handleSelector: { type: String, default: '.DragHandle' },
    positionMode: { type: String, default: 'index' },
  };

  declare readonly handleValue:boolean;
  declare readonly handleSelectorValue:string;
  declare readonly positionModeValue:string;

  private targetConfigs:TargetConfig[] = [];
  private containers:HTMLElement[] = [];
  private cleanupMap = new WeakMap<Element, CleanupFn>();
  private allCleanups = new Set<CleanupFn>();
  private monitorCleanup:CleanupFn|null = null;
  private dragOriginContainer:Element|null = null;
  private dragOriginNextSibling:Element|null = null;

  connect() {
    this.monitorCleanup = monitorForElements({
      onDragStart: ({ source }) => {
        if (!this.ownsDraggable(source.element)) return;
        source.element.setAttribute('data-dragging', 'source');
        document.body.setAttribute('data-dragging', 'active');
        this.ariaPressedTarget(source.element)?.setAttribute('aria-pressed', 'true');
        preventUnhandled.start();
      },
      onDrop: ({ source }) => {
        if (!this.ownsDraggable(source.element)) return;
        source.element.removeAttribute('data-dragging');
        document.body.removeAttribute('data-dragging');
        this.ariaPressedTarget(source.element)?.setAttribute('aria-pressed', 'false');
        preventUnhandled.stop();
        this.clearAllDropEdges();
      },
    });
  }

  disconnect() {
    document.body.removeAttribute('data-dragging');
    this.monitorCleanup?.();
    this.monitorCleanup = null;
    for (const cleanup of this.allCleanups) {
      cleanup();
    }
    this.allCleanups.clear();
  }

  containerTargetConnected(target:HTMLElement) {
    const container = this.resolveContainerElement(target);
    const targetConfig:TargetConfig = {
      container,
      allowedDragType: target.getAttribute('data-target-allowed-drag-type'),
      targetId: target.getAttribute('data-target-id'),
    };

    this.targetConfigs.push(targetConfig);
    this.containers.push(container);

    const dropCleanup = dropTargetForElements({
      element: container,
      canDrop: ({ source }) => this.canDropInContainer(source.element, container),
      onDragEnter: ({ self }) => {
        if (container.children.length === 0 || this.isEmptyPlaceholderOnly(container)) {
          const edge = extractClosestEdge(self.data);
          if (edge) {
            container.setAttribute('data-drop-edge', edge);
          }
        }
      },
      onDrag: ({ self }) => {
        if (container.children.length === 0 || this.isEmptyPlaceholderOnly(container)) {
          const edge = extractClosestEdge(self.data);
          if (edge) {
            container.setAttribute('data-drop-edge', edge);
          }
        }
      },
      onDragLeave: () => {
        container.removeAttribute('data-drop-edge');
      },
      onDrop: () => {
        container.removeAttribute('data-drop-edge');
      },
      getData: ({ input, element }) => {
        return attachClosestEdge({}, {
          element,
          input,
          allowedEdges: ['top', 'bottom'],
        });
      },
    });

    const scrollTargets:Element[] = this.scrollContainerTargets.length > 0
      ? this.scrollContainerTargets
      : [document.getElementById('content-body')].filter(Boolean) as Element[];

    const scrollCleanups = scrollTargets.map(scrollTarget =>
      autoScrollForElements({
        element: scrollTarget as HTMLElement,
      }),
    );

    const cleanup = combine(dropCleanup, ...scrollCleanups);
    this.cleanupMap.set(target, cleanup);
    this.allCleanups.add(cleanup);
  }

  containerTargetDisconnected(target:HTMLElement) {
    const container = this.resolveContainerElement(target);
    const index = this.containers.indexOf(container);
    if (index !== -1) {
      this.containers.splice(index, 1);
      this.targetConfigs.splice(index, 1);
    }

    const cleanup = this.cleanupMap.get(target);
    if (cleanup) {
      cleanup();
      this.cleanupMap.delete(target);
      this.allCleanups.delete(cleanup);
    }
  }

  itemTargetConnected(el:HTMLElement) {
    if (!this.isDraggableElement(el)) return;

    const dragHandle = this.handleValue
      ? el.querySelector<Element>(this.handleSelectorValue) ?? undefined
      : undefined;

    const dragCleanup = draggable({
      element: el,
      dragHandle,
      canDrag: ({ element, dragHandle: handle }) => this.canStartDrag(element, handle ?? element),
      onDragStart: () => {
        this.dragOriginContainer = el.parentElement;
        this.dragOriginNextSibling = el.nextElementSibling;
      },
      onDrop: ({ location }) => {
        void this.handleDrop(el, location.current.dropTargets);
      },
    });

    const dropOnItemCleanup = dropTargetForElements({
      element: el,
      canDrop: ({ source }) => {
        if (source.element === el) return false;
        return this.canDropOnItem(source.element, el);
      },
      getData: ({ input, element }) => {
        return attachClosestEdge({}, {
          element,
          input,
          allowedEdges: ['top', 'bottom'],
        });
      },
      onDragEnter: ({ self }) => {
        const edge = extractClosestEdge(self.data);
        if (edge) el.setAttribute('data-drop-edge', edge);
      },
      onDrag: ({ self }) => {
        const edge = extractClosestEdge(self.data);
        if (edge) el.setAttribute('data-drop-edge', edge);
      },
      onDragLeave: () => {
        el.removeAttribute('data-drop-edge');
      },
      onDrop: () => {
        el.removeAttribute('data-drop-edge');
      },
    });

    const cleanup = combine(dragCleanup, dropOnItemCleanup);
    this.cleanupMap.set(el, cleanup);
    this.allCleanups.add(cleanup);
  }

  itemTargetDisconnected(el:HTMLElement) {
    const cleanup = this.cleanupMap.get(el);
    if (cleanup) {
      cleanup();
      this.cleanupMap.delete(el);
      this.allCleanups.delete(cleanup);
    }
  }

  private async handleDrop(el:HTMLElement, dropTargets:{ element:Element; data:Record<string|symbol, unknown> }[]) {
    if (dropTargets.length === 0) {
      this.clearDragOrigin();
      return;
    }

    const { targetContainer, insertionEl, edge } = this.resolveDropTarget(el, dropTargets);
    if (!targetContainer) {
      this.clearDragOrigin();
      return;
    }

    const beforeDropEvent = this.dispatch('before-drop', {
      detail: { el, target: targetContainer, sourceContainer: this.dragOriginContainer },
      cancelable: true,
    }) as Event;

    if (beforeDropEvent.defaultPrevented) {
      this.clearDragOrigin();
      return;
    }

    if (insertionEl && insertionEl !== el) {
      if (edge === 'bottom') {
        insertionEl.after(el);
      } else {
        insertionEl.before(el);
      }
    } else if (!insertionEl) {
      targetContainer.appendChild(el);
    }

    const dropUrl = el.getAttribute('data-drop-url');
    if (!dropUrl) {
      this.clearDragOrigin();
      return;
    }

    const data = this.buildData(el, targetContainer);
    this.dispatch('build-data', { detail: { data, el, target: targetContainer } });

    let success = false;
    try {
      const request = new FetchRequest('put', dropUrl, { body: data, responseKind: 'turbo-stream' });
      const response = await request.perform();

      if (!response.ok) {
        this.revertDrop(el);
        debugLog(`Failed to sort item: ${response.statusCode}`);
      } else {
        success = true;
      }
    } catch (error) {
      this.revertDrop(el);
      debugLog('Failed to sort item due to request error', error);
    } finally {
      this.dispatch('after-drop', { detail: { el, target: targetContainer, success } });
      this.clearDragOrigin();
    }
  }

  private resolveDropTarget(
    draggedEl:HTMLElement,
    dropTargets:{ element:Element; data:Record<string|symbol, unknown> }[],
  ):{ targetContainer:Element|null; insertionEl:Element|null; edge:string|null } {
    let insertionEl:Element|null = null;
    let edge:string|null = null;
    let targetContainer:Element|null = null;

    for (const dropTarget of dropTargets) {
      if (dropTarget.element instanceof HTMLElement && this.containers.includes(dropTarget.element)) {
        targetContainer = dropTarget.element;
        break;
      }

      if (this.itemTargets.includes(dropTarget.element as HTMLElement) && dropTarget.element !== draggedEl) {
        insertionEl = dropTarget.element;
        edge = extractClosestEdge(dropTarget.data) as string|null;
        targetContainer = this.findContainerForElement(dropTarget.element);
        break;
      }
    }

    return { targetContainer, insertionEl, edge };
  }

  private findContainerForElement(el:Element):Element|null {
    for (const container of this.containers) {
      if (container.contains(el)) {
        return container;
      }
    }
    return null;
  }

  private buildData(el:Element, target:Element):FormData {
    const data = new FormData();

    if (this.positionModeValue === 'prev_id') {
      data.append('prev_id', this.resolveTargetPrevious(el) ?? '');
    } else {
      data.append('position', this.resolveTargetPosition(el, target).toString());
    }

    const targetConfig = this.targetConfigs.find((config) => config.container === target);
    const targetId = targetConfig?.targetId as string|undefined;

    if (targetId) {
      data.append('target_id', targetId.toString());
    }

    return data;
  }

  private canStartDrag(el:Element|null|undefined, handle:Element|null|undefined):boolean {
    if (!this.isDraggableElement(el)) {
      return false;
    }

    if (!this.handleValue) {
      return closestInteractiveElement(handle ?? null, el) == null;
    }

    return handle?.closest(this.handleSelectorValue) != null;
  }

  private canDropInContainer(sourceEl:HTMLElement, container:Element):boolean {
    const targetConfig = this.targetConfigs.find((config) => config.container === container);
    if (!targetConfig?.allowedDragType) return true;

    const draggableType = sourceEl.getAttribute('data-draggable-type');
    return draggableType === targetConfig.allowedDragType;
  }

  private canDropOnItem(sourceEl:HTMLElement, targetItem:HTMLElement):boolean {
    const container = this.findContainerForElement(targetItem);
    if (!container) return false;
    return this.canDropInContainer(sourceEl, container);
  }

  private isDraggableElement(el:Element|null|undefined):boolean {
    return el instanceof HTMLElement
      && el.getAttribute('data-empty-list-item') !== 'true'
      && el.dataset.draggableType !== undefined
      && el.dataset.dropUrl !== undefined;
  }

  private resolveContainerElement(target:HTMLElement):HTMLElement {
    const accessor = target.getAttribute('data-target-container-accessor');
    if (!accessor) {
      return target;
    }
    const container = target.querySelector<HTMLElement>(accessor);
    invariant(container, `Expected container element matching "${accessor}"`);
    return container;
  }

  private resolveTargetPrevious(el:Element):string|null {
    return el.previousElementSibling?.getAttribute('data-draggable-id') ?? null;
  }

  private resolveTargetPosition(el:Element, container:Element):number {
    let targetPosition = Array.from(container.children).indexOf(el);

    if (container.children.length > 0 && container.children[0].getAttribute('data-empty-list-item') === 'true') {
      targetPosition -= 1;
    }

    return targetPosition + 1;
  }

  private ariaPressedTarget(el:Element):Element|null {
    if (!this.handleValue) return null;
    return el.querySelector(this.handleSelectorValue);
  }

  private ownsDraggable(el:HTMLElement):boolean {
    return this.itemTargets.includes(el);
  }

  private revertDrop(el:Element) {
    if (this.dragOriginContainer) {
      if (this.dragOriginNextSibling?.parentNode === this.dragOriginContainer) {
        this.dragOriginContainer.insertBefore(el, this.dragOriginNextSibling);
      } else {
        this.dragOriginContainer.appendChild(el);
      }
    }
  }

  private clearDragOrigin() {
    this.dragOriginContainer = null;
    this.dragOriginNextSibling = null;
  }

  private clearAllDropEdges() {
    for (const item of this.itemTargets) {
      item.removeAttribute('data-drop-edge');
    }
    for (const container of this.containers) {
      container.removeAttribute('data-drop-edge');
    }
  }

  private isEmptyPlaceholderOnly(container:Element):boolean {
    return container.children.length === 1
      && container.children[0].getAttribute('data-empty-list-item') === 'true';
  }
}

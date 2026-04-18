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
import invariant from 'tiny-invariant';
import { DragDropManager, Droppable } from '@dnd-kit/dom';
import type { BeforeDragStartEvent } from '@dnd-kit/dom';
import { Sortable } from '@dnd-kit/dom/sortable';

interface TargetConfig {
  container:HTMLElement;
  allowedDragType:string|null;
  targetId:string|null;
}

const ACTIVE_PREVIEW_ATTRIBUTE = 'data-generic-dnd-preview-active';

export default class GenericDragAndDropController extends Controller {
  static targets = ['container', 'scrollContainer', 'item'];

  static values = {
    handleSelector: { type: String, default: '.DragHandle' },
    positionMode: { type: String, default: 'index' },
  };

  declare readonly containerTargets:HTMLElement[];
  declare readonly scrollContainerTargets:HTMLElement[];
  declare readonly itemTargets:HTMLElement[];
  declare readonly handleSelectorValue:string;
  declare readonly positionModeValue:string;

  private manager:DragDropManager|null = null;
  private containerConfigs = new Map<HTMLElement, TargetConfig>();
  private droppables = new Map<HTMLElement, Droppable>();
  private sortables = new Map<HTMLElement, Sortable>();
  private unsubscribers:(() => void)[] = [];
  private uidCounter = 0;
  private turboMorphAbort:AbortController|null = null;
  private domObserver:MutationObserver|null = null;
  private currentDropOperation:{ target?:unknown; shape?:{ current?:{ center?:{ y:number } } }; position?:{ current?:{ y:number } } }|null = null;

  // Saved on dragstart, used to revert the DOM on server-side drop failure
  // (dnd-kit's OptimisticSortingPlugin has already moved the element by then).
  private dragOriginSource:Element|null = null;
  private dragOriginNextSibling:Element|null = null;
  private draggedElement:HTMLElement|null = null;

  connect() {
    this.createManager();

    // Turbo morph preserves DOM nodes across refresh when IDs match. Stimulus
    // does not fire target-connected/disconnected for preserved elements, so
    // our Sortable/Droppable references go stale (their internal state may
    // conflict with attributes/children morph mutated in place). Listen for
    // `turbo:morph-element` and re-register the affected entity. Same shape
    // as the Pragmatic DnD spike workaround in commit 9ec12351841.
    this.turboMorphAbort = new AbortController();
    this.element.addEventListener('turbo:morph-element', this.onTurboMorphElement, {
      signal: this.turboMorphAbort.signal,
    });
    this.domObserver = new MutationObserver((mutations) => this.onDomMutations(mutations));
    this.domObserver.observe(this.element, {
      childList: true,
      subtree: true,
    });
  }

  disconnect() {
    this.turboMorphAbort?.abort();
    this.turboMorphAbort = null;
    this.domObserver?.disconnect();
    this.domObserver = null;
    this.unsubscribers.forEach((u) => u());
    this.unsubscribers = [];
    this.sortables.forEach((s) => s.destroy());
    this.sortables.clear();
    this.droppables.forEach((d) => d.destroy());
    this.droppables.clear();
    this.containerConfigs.clear();
    this.manager?.destroy();
    this.manager = null;
  }

  containerTargetConnected(target:HTMLElement) {
    this.createManager();

    // eslint-disable-next-line no-console
    console.log('[dnd] containerTargetConnected', target);
    const container = this.resolveContainerElement(target);
    const config:TargetConfig = {
      container,
      allowedDragType: target.getAttribute('data-target-allowed-drag-type'),
      targetId: target.getAttribute('data-target-id'),
    };
    this.containerConfigs.set(container, config);

    if (this.manager) {
      const droppable = new Droppable(
        {
          id: `container-${this.nextUid()}`,
          element: container,
          accept: config.allowedDragType ?? undefined,
        },
        this.manager,
      );
      this.droppables.set(container, droppable);
    }
  }

  containerTargetDisconnected(target:HTMLElement) {
    const container = this.resolveContainerElement(target);
    const droppable = this.droppables.get(container);
    if (droppable) {
      droppable.destroy();
      this.droppables.delete(container);
    }
    this.containerConfigs.delete(container);
  }

  itemTargetConnected(item:HTMLElement) {
    this.createManager();
    // eslint-disable-next-line no-console
    console.log('[dnd] itemTargetConnected', item.getAttribute('data-draggable-id'), item);
    if (this.isPlaceholderElement(item)) return;
    if (!this.manager) return;

    const container = this.findContainerFor(item);
    if (!container) return;

    const config = this.containerConfigs.get(container);
    if (!config) return;

    const draggableId = item.getAttribute('data-draggable-id');
    const draggableType = item.getAttribute('data-draggable-type');
    if (!draggableId) return;

    const handleEl = item.querySelector<HTMLElement>(this.handleSelectorValue);
    const index = this.itemsForContainer(container).indexOf(item);

    const sortable = new Sortable(
      {
        id: `sortable-${draggableId}`,
        element: item,
        handle: handleEl ?? undefined,
        group: config.allowedDragType ?? undefined,
        type: draggableType ?? undefined,
        accept: config.allowedDragType ?? undefined,
        index: Math.max(0, index),
      },
      this.manager,
    );
    this.sortables.set(item, sortable);

    this.reindexItems();
  }

  itemTargetDisconnected(item:HTMLElement) {
    // eslint-disable-next-line no-console
    console.log('[dnd] itemTargetDisconnected', item.getAttribute('data-draggable-id'), item);
    if (this.isPlaceholderElement(item)) return;
    const sortable = this.sortables.get(item);
    if (sortable) {
      sortable.destroy();
      this.sortables.delete(item);
    }
    this.reindexItems();
  }

  cancelDrag() {
    if (this.draggedElement) {
      this.revertDrop(this.draggedElement);
    }
  }

  private onTurboMorphElement = (event:Event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;

    const role = target.getAttribute(this.targetAttributeName());
    if (role !== 'item' && role !== 'container') return;

    // eslint-disable-next-line no-console
    console.log('[dnd] turbo:morph-element', role, target.getAttribute('data-draggable-id') ?? target.getAttribute('data-target-id'));

    if (role === 'item') {
      const existing = this.sortables.get(target);
      if (existing) {
        existing.destroy();
        this.sortables.delete(target);
      }
      this.itemTargetConnected(target);
      return;
    }

    if (role === 'container') {
      const container = this.resolveContainerElement(target);
      const existing = this.droppables.get(container);
      if (existing) {
        existing.destroy();
        this.droppables.delete(container);
      }
      this.containerConfigs.delete(container);
      this.containerTargetConnected(target);
    }
  };

  private onDomMutations(mutations:MutationRecord[]) {
    if (this.draggedElement) return;

    const affectedItems = new Set<HTMLElement>();
    for (const mutation of mutations) {
      const item = this.closestManagedTarget(mutation.target, 'item');
      if (item) {
        affectedItems.add(item);
      }

      mutation.addedNodes.forEach((node) => {
        const itemTarget = this.closestManagedTarget(node, 'item');
        if (itemTarget && !this.nodeIsManagedTarget(node, 'item')) {
          affectedItems.add(itemTarget);
        }
      });

      mutation.removedNodes.forEach((node) => {
        const itemTarget = this.closestManagedTarget(node, 'item');
        if (itemTarget && !this.nodeIsManagedTarget(node, 'item')) {
          affectedItems.add(itemTarget);
        }
      });
    }

    affectedItems.forEach((item) => this.refreshItemTarget(item));
  }

  private createManager() {
    if (this.manager) return;

    // Default preset includes AutoScroller, Accessibility, Cursor, Feedback,
    // and PreventSelection. We pin source dimensions in beforedragstart,
    // before Feedback performs its initial measurement, because the feedback
    // plugin's CSS var-based width/height feedback-loops to 0 once the <li>
    // is popover'd (its layout size came from the parent <ul> flex context,
    // which doesn't follow it into the top layer).
    this.manager = new DragDropManager();

    this.unsubscribers.push(
      this.manager.monitor.addEventListener('beforedragstart', this.onBeforeDragStart),
      this.manager.monitor.addEventListener('dragstart', this.onDragStart),
      this.manager.monitor.addEventListener('dragend', (event) => {
        void this.onDragEnd(event);
      }),
    );
  }

  private onBeforeDragStart = (event:BeforeDragStartEvent):void => {
    const el = this.resolveDragSourceElement(event);
    if (!el) return;

    el.setAttribute(ACTIVE_PREVIEW_ATTRIBUTE, '');

    const rect = el.getBoundingClientRect();
    if (rect.width > 0 && rect.height > 0) {
      el.style.setProperty('width', `${rect.width}px`, 'important');
      el.style.setProperty('height', `${rect.height}px`, 'important');
    }

    this.draggedElement = el;
    this.dragOriginSource = el.parentElement;
    this.dragOriginNextSibling = el.nextElementSibling;

    const handle = el.querySelector(this.handleSelectorValue);
    handle?.setAttribute('aria-pressed', 'true');
  };

  private onDragStart = ():void => {
    const el = this.draggedElement ?? this.resolveDraggedElement();
    // eslint-disable-next-line no-console
    console.log('[dnd] dragstart', el?.getAttribute('data-draggable-id'), el);
  };

  private onDragEnd = async (event:{ canceled:boolean; operation?:{ target?:unknown } }):Promise<void> => {
    const el = this.draggedElement ?? this.resolveDraggedElement();
    // eslint-disable-next-line no-console
    console.log('[dnd] dragend', {
      canceled: event.canceled,
      draggedId: el?.getAttribute('data-draggable-id'),
      sortableCount: this.sortables.size,
      droppableCount: this.droppables.size,
    });
    if (!el) return;

    const handle = el.querySelector(this.handleSelectorValue);
    handle?.setAttribute('aria-pressed', 'false');

    // Keep the visual preview pinned until the drop/revert work finishes.
    el.style.removeProperty('width');
    el.style.removeProperty('height');

    try {
      if (event.canceled) return;

      this.currentDropOperation = event.operation ?? null;
      const target = this.resolveDropContainer(event, el);
      if (!target) return;
      this.syncDomToDropTarget(el, target);

      await this.drop(el, target, this.dragOriginSource, this.dragOriginNextSibling);
    } finally {
      this.currentDropOperation = null;
      el.removeAttribute(ACTIVE_PREVIEW_ATTRIBUTE);
      this.dragOriginSource = null;
      this.dragOriginNextSibling = null;
      this.draggedElement = null;
      // eslint-disable-next-line no-console
      console.log('[dnd] dragend cleanup done, sortables=', this.sortables.size);
    }
  };

  // Subclass hook: meetings/drag-and-drop.controller overrides this to prompt
  // on unsaved changes, then delegate to super.drop(). Signature preserved
  // from the Dragula-era implementation.
  protected accepts(el:Element, target:Element, _source:Element|null, _sibling:Element|null):boolean {
    const config = this.containerConfigs.get(target as HTMLElement);
    const acceptedDragType = config?.allowedDragType as string|undefined;
    const draggableType = el.getAttribute('data-draggable-type');

    if (draggableType !== acceptedDragType) {
      debugLog('Element is not allowed to be dropped here');
      return false;
    }

    return true;
  }

  async drop(el:Element, target:Element, _source:Element|null, _sibling:Element|null) {
    const dropUrl = el.getAttribute('data-drop-url');
    if (!dropUrl) return;

    const data = this.buildData(el, target);

    try {
      const request = new FetchRequest('put', dropUrl, { body: data, responseKind: 'turbo-stream' });
      const response = await request.perform();

      if (!response.ok) {
        this.revertDrop(el);
        debugLog(`Failed to sort item: ${response.statusCode}`);
      }
    } catch (error) {
      this.revertDrop(el);
      debugLog('Failed to sort item due to request error', error);
    }
  }

  protected buildData(el:Element, target:Element):FormData {
    const data = new FormData();

    if (this.positionModeValue === 'prev_id') {
      data.append('prev_id', this.resolveTargetPrevious(el) ?? '');
    } else {
      data.append('position', this.resolveTargetPosition(el, target).toString());
    }

    const config = this.containerConfigs.get(target as HTMLElement);
    const targetId = config?.targetId as string|undefined;
    if (targetId) {
      data.append('target_id', targetId.toString());
    }

    return data;
  }

  private revertDrop(el:Element) {
    if (!this.dragOriginSource) return;

    if (this.dragOriginNextSibling?.parentNode === this.dragOriginSource) {
      this.dragOriginSource.insertBefore(el, this.dragOriginNextSibling);
    } else {
      this.dragOriginSource.appendChild(el);
    }

    // After a manual DOM move the dnd-kit Sortable indexes are stale.
    // Re-sync them to current DOM order so subsequent drags behave correctly.
    this.reindexItems();
  }

  private reindexItems() {
    this.containerConfigs.forEach((_config, container) => {
      this.itemsForContainer(container).forEach((el, idx) => {
        const sortable = this.sortables.get(el);
        if (sortable) sortable.index = idx;
      });
    });
  }

  private realItemTargets():HTMLElement[] {
    return this.itemTargets.filter((el) => !this.isPlaceholderElement(el));
  }

  private isPlaceholderElement(el:Element):boolean {
    return el.hasAttribute('data-dnd-placeholder');
  }

  // If the target has a container accessor, use that as the container instead
  // of the element itself. Needed e.g. in Primer's BorderBox where drag-and-drop
  // data attributes cannot be placed on the inner ul.
  private resolveContainerElement(target:HTMLElement):HTMLElement {
    const accessor = target.getAttribute('data-target-container-accessor');
    if (!accessor) return target;
    const container = target.querySelector<HTMLElement>(accessor);
    invariant(container, `Expected container element matching "${accessor}"`);
    return container;
  }

  private findContainerFor(item:HTMLElement):HTMLElement|null {
    let current = item.parentElement;
    while (current) {
      if (this.containerConfigs.has(current)) return current;
      current = current.parentElement;
    }
    return null;
  }

  private itemsForContainer(container:HTMLElement):HTMLElement[] {
    return this.realItemTargets().filter((item) => this.findContainerFor(item) === container);
  }

  private resolveDraggedElement():HTMLElement|null {
    const source = this.manager?.dragOperation?.source;
    if (!source) return null;
    const el = (source as unknown as { element?:HTMLElement }).element;
    return el ?? null;
  }

  private resolveDragSourceElement(event:{ operation?:{ source?:unknown } }):HTMLElement|null {
    const source = event.operation?.source;
    const el = (source as { element?:HTMLElement }|undefined)?.element;
    return el ?? null;
  }

  private resolveDropContainer(event:{ operation?:{ target?:unknown } }, draggedElement:HTMLElement):HTMLElement|null {
    const dropTargetElement = (event.operation?.target as { element?:HTMLElement }|undefined)?.element;
    const draggableType = draggedElement.getAttribute('data-draggable-type');
    if (dropTargetElement instanceof HTMLElement) {
      const matchingContainer = this.resolveMatchingDropContainer(dropTargetElement, draggableType);
      if (matchingContainer) {
        return matchingContainer;
      }
    }

    return this.findContainerFor(draggedElement);
  }

  // Returns the data-draggable-id of the element preceding el in its container,
  // or null if el is the first item (signals "move to top").
  private resolveTargetPrevious(el:Element):string|null {
    return el.previousElementSibling?.getAttribute('data-draggable-id') ?? null;
  }

  private resolveTargetPosition(el:Element, container:Element):number {
    const targetContainer = container as HTMLElement;
    const currentItems = this.itemsForContainer(targetContainer);
    const dropTargetElement = this.resolveDropTargetElement();
    if (dropTargetElement && targetContainer.contains(dropTargetElement)) {
      const targetItem = this.resolveDropTargetItem(targetContainer, dropTargetElement);
      const targetIndex = targetItem ? currentItems.indexOf(targetItem) : -1;
      if (targetIndex >= 0 && targetItem !== el) {
        return targetIndex + (this.isDropAfterTarget() ? 2 : 1);
      }
    }

    const currentIndex = currentItems.indexOf(el as HTMLElement);
    if (currentIndex >= 0) {
      return currentIndex + 1;
    }

    if (dropTargetElement === targetContainer) {
      return this.isDropAfterTarget() ? currentItems.length + 1 : 1;
    }

    return currentItems.length + 1;
  }

  private syncDomToDropTarget(el:Element, container:Element):void {
    const targetContainer = container as HTMLElement;
    const draggedElement = el as HTMLElement;
    const dropTargetElement = this.resolveDropTargetElement();

    if (dropTargetElement && targetContainer.contains(dropTargetElement)) {
      const targetItem = this.resolveDropTargetItem(targetContainer, dropTargetElement);
      if (targetItem && targetItem !== draggedElement) {
        targetItem.insertAdjacentElement(this.isDropAfterTarget() ? 'afterend' : 'beforebegin', draggedElement);
        this.reindexItems();
        return;
      }
    }

    if (dropTargetElement === targetContainer) {
      if (this.isDropAfterTarget()) {
        targetContainer.appendChild(draggedElement);
      } else {
        targetContainer.insertBefore(draggedElement, targetContainer.firstElementChild);
      }
      this.reindexItems();
      return;
    }

    if (!targetContainer.contains(draggedElement)) {
      targetContainer.appendChild(draggedElement);
      this.reindexItems();
    }
  }

  private resolveMatchingDropContainer(element:HTMLElement, draggableType:string|null):HTMLElement|null {
    if (this.matchesDropContainer(element, draggableType)) {
      return element;
    }

    const descendantMatch = Array.from(this.containerConfigs.keys()).find((container) =>
      element.contains(container) && this.matchesDropContainer(container, draggableType));
    if (descendantMatch) {
      return descendantMatch;
    }

    let current = element.parentElement;
    while (current) {
      if (this.matchesDropContainer(current, draggableType)) {
        return current;
      }
      current = current.parentElement;
    }

    return null;
  }

  private matchesDropContainer(container:HTMLElement, draggableType:string|null):boolean {
    const config = this.containerConfigs.get(container);
    return !!config && config.allowedDragType === draggableType;
  }

  private resolveDropTargetElement():HTMLElement|null {
    const target = this.currentDropOperation?.target as { element?:HTMLElement }|undefined;
    return target?.element ?? null;
  }

  private resolveDropTargetItem(container:HTMLElement, dropTargetElement:HTMLElement):HTMLElement|null {
    let current:HTMLElement|null = dropTargetElement;

    while (current) {
      if (this.sortables.has(current) && this.findContainerFor(current) === container) {
        return current;
      }

      if (current === container) {
        return null;
      }

      current = current.parentElement;
    }

    return null;
  }

  private isDropAfterTarget():boolean {
    const currentCenterY = this.currentDropOperation?.shape?.current?.center?.y ?? this.currentDropOperation?.position?.current?.y;
    const targetCenterY = (this.currentDropOperation?.target as { shape?:{ center?:{ y:number } } }|undefined)?.shape?.center?.y;

    if (typeof currentCenterY !== 'number' || typeof targetCenterY !== 'number') {
      return true;
    }

    return Math.round(currentCenterY) > Math.round(targetCenterY);
  }

  private nextUid():string {
    this.uidCounter += 1;
    return this.uidCounter.toString();
  }

  private targetAttributeName():string {
    return `data-${this.identifier}-target`;
  }

  private refreshItemTarget(item:HTMLElement) {
    if (!this.sortables.has(item)) return;

    const existing = this.sortables.get(item);
    if (existing) {
      existing.destroy();
      this.sortables.delete(item);
    }

    this.itemTargetConnected(item);
  }

  private closestManagedTarget(node:Node, role:'item'|'container'):HTMLElement|null {
    const element = node instanceof HTMLElement ? node : node.parentElement;
    return element?.closest<HTMLElement>(`[${this.targetAttributeName()}="${role}"]`) ?? null;
  }

  private isManagedTarget(element:HTMLElement, role:'item'|'container'):boolean {
    return element.getAttribute(this.targetAttributeName()) === role;
  }

  private nodeIsManagedTarget(node:Node, role:'item'|'container'):boolean {
    return node instanceof HTMLElement && this.isManagedTarget(node, role);
  }
}

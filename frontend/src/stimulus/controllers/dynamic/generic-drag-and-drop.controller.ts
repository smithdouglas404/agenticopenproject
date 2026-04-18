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
import { AutoScroller, DragDropManager, Droppable, type BeforeDragStartEvent, type DragEndEvent } from '@dnd-kit/dom';
import { Sortable } from '@dnd-kit/dom/sortable';
import { debugLog } from 'core-app/shared/helpers/debug_output';

interface TargetConfig {
  allowedDragType:string|null;
  targetId:string|null;
}

export default class GenericDragAndDropController extends Controller {
  static targets = ['container', 'scrollContainer', 'item'];

  declare readonly containerTargets:HTMLElement[];
  declare readonly scrollContainerTargets:HTMLElement[];
  declare readonly itemTargets:HTMLElement[];

  static values = {
    handleSelector: { type: String, default: '.DragHandle' },
    positionMode: { type: String, default: 'index' },
  };

  declare readonly handleSelectorValue:string;
  declare readonly positionModeValue:string;

  private manager:DragDropManager|null = null;
  private containerConfigs = new Map<HTMLElement, TargetConfig>();
  private droppables = new Map<HTMLElement, Droppable>();
  private sortables = new Map<HTMLElement, Sortable>();
  private registrations:(() => void)[] = [];
  private dragOriginSource:Element|null = null;
  private dragOriginNextSibling:Element|null = null;
  private draggedElement:HTMLElement|null = null;

  connect() {
    this.destroyManager();
    this.manager = this.createManager();

    this.registrations.push(
      this.manager.monitor.addEventListener('beforedragstart', (event) => this.onBeforeDragStart(event)),
      this.manager.monitor.addEventListener('dragend', (event) => {
        void this.onDragEnd(event);
      }),
    );

    this.containerTargets.forEach((target) => this.containerTargetConnected(target));
    this.itemTargets.forEach((target) => this.itemTargetConnected(target));
  }

  disconnect() {
    this.destroyManager();
  }

  containerTargetConnected(target:HTMLElement) {
    if (!this.manager || this.containerConfigs.has(target)) {
      return;
    }

    const config:TargetConfig = {
      allowedDragType: target.getAttribute('data-target-allowed-drag-type'),
      targetId: target.getAttribute('data-target-id'),
    };

    const droppable = new Droppable(
      {
        id: this.containerIdentifier(target),
        element: target,
        type: 'container',
        accept: config.allowedDragType ?? undefined,
      },
      this.manager,
    );

    this.containerConfigs.set(target, config);
    this.droppables.set(target, droppable);
    droppable.register();
    this.reindexItems();
  }

  containerTargetDisconnected(target:HTMLElement) {
    this.destroyDroppable(target);
    this.reindexItems();
  }

  itemTargetConnected(target:HTMLElement) {
    if (!this.manager || this.isPlaceholderElement(target) || this.sortables.has(target)) {
      return;
    }

    const container = this.findContainerFor(target);
    if (!container) {
      return;
    }

    const config = this.containerConfigs.get(container);
    const draggableId = target.getAttribute('data-draggable-id');
    if (!draggableId) {
      return;
    }

    const sortable = new Sortable(
      {
        id: this.sortableIdentifier(target),
        element: target,
        target,
        handle: target.querySelector(this.handleSelectorValue) ?? undefined,
        group: config?.allowedDragType ?? undefined,
        index: this.realItemsInContainer(container).indexOf(target),
        type: target.getAttribute('data-draggable-type') ?? undefined,
        accept: config?.allowedDragType ?? undefined,
      },
      this.manager,
    );

    this.sortables.set(target, sortable);
    sortable.register();
    this.reindexItems();
  }

  itemTargetDisconnected(target:HTMLElement) {
    this.destroySortable(target);
    this.reindexItems();
  }

  cancelDrag() {
    if (this.draggedElement) {
      this.revertDrop(this.draggedElement);
    }
  }

  protected accepts(el:Element, target:Element, _source:Element|null, _sibling:Element|null) {
    const targetConfig = target instanceof HTMLElement ? this.containerConfigs.get(target) : undefined;
    const acceptedDragType = targetConfig?.allowedDragType;
    const draggableType = el.getAttribute('data-draggable-type');

    if (acceptedDragType && draggableType !== acceptedDragType) {
      debugLog('Element is not allowed to be dropped here');
      return false;
    }

    return true;
  }

  async drop(el:Element, target:Element, _source:Element|null, _sibling:Element|null) {
    const dropUrl = el.getAttribute('data-drop-url');
    const data = this.buildData(el, target);

    if (!dropUrl) {
      return;
    }

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
    } finally {
      this.reindexItems();
    }
  }

  protected buildData(el:Element, target:Element):FormData {
    const data = new FormData();

    if (this.positionModeValue === 'prev_id') {
      data.append('prev_id', this.resolveTargetPrevious(el) ?? '');
    } else {
      data.append('position', this.resolveTargetPosition(el, target).toString());
    }

    const targetId = target instanceof HTMLElement ? this.containerConfigs.get(target)?.targetId : null;

    if (targetId) {
      data.append('target_id', targetId.toString());
    }

    return data;
  }

  private createManager() {
    return new DragDropManager({
      plugins: (defaults) => defaults.map((plugin) => (
        plugin === AutoScroller
          ? AutoScroller.configure({ acceleration: 10, threshold: { x: 0.2, y: 0.2 } })
          : plugin
      )),
    });
  }

  private destroyManager() {
    this.registrations.splice(0).forEach((cleanup) => cleanup());
    this.sortables.forEach((_sortable, element) => this.destroySortable(element));
    this.droppables.forEach((_droppable, element) => this.destroyDroppable(element));
    this.containerConfigs.clear();
    this.manager?.destroy();
    this.manager = null;
    this.dragOriginSource = null;
    this.dragOriginNextSibling = null;
    this.draggedElement = null;
  }

  private destroySortable(target:HTMLElement) {
    const sortable = this.sortables.get(target);
    if (!sortable) {
      return;
    }

    sortable.unregister();
    sortable.destroy();
    this.sortables.delete(target);
  }

  private destroyDroppable(target:HTMLElement) {
    const droppable = this.droppables.get(target);
    if (!droppable) {
      return;
    }

    droppable.unregister();
    droppable.destroy();
    this.droppables.delete(target);
    this.containerConfigs.delete(target);
  }

  private revertDrop(el:Element) {
    if (!this.dragOriginSource) {
      return;
    }

    if (this.dragOriginNextSibling?.parentNode === this.dragOriginSource) {
      this.dragOriginSource.insertBefore(el, this.dragOriginNextSibling);
    } else {
      this.dragOriginSource.appendChild(el);
    }

    this.reindexItems();
  }

  private resolveDraggedElement(event:{ operation:{ source?:{ element?:Element }|null } }):HTMLElement|null {
    const element = event.operation.source?.element;

    return element instanceof HTMLElement ? element : null;
  }

  private onBeforeDragStart(event:BeforeDragStartEvent) {
    const element = this.resolveDraggedElement(event);
    if (!element) {
      return;
    }

    const rect = element.getBoundingClientRect();
    if (rect.width > 0 && rect.height > 0) {
      element.style.setProperty('width', `${rect.width}px`, 'important');
      element.style.setProperty('height', `${rect.height}px`, 'important');
    }

    this.draggedElement = element;
    this.dragOriginSource = element.parentElement;
    this.dragOriginNextSibling = element.nextElementSibling;
    element.querySelector(this.handleSelectorValue)?.setAttribute('aria-pressed', 'true');
  }

  private async onDragEnd(event:DragEndEvent) {
    const element = this.draggedElement ?? this.resolveDraggedElement(event);

    try {
      if (!element || event.canceled) {
        return;
      }

      const target = this.findContainerFor(element);
      if (!target) {
        return;
      }

      const source = this.dragOriginSource;
      const sibling = element.nextElementSibling;

      if (!this.accepts(element, target, source, sibling)) {
        this.revertDrop(element);
        return;
      }

      await this.drop(element, target, source, sibling);
    } finally {
      if (element) {
        element.querySelector(this.handleSelectorValue)?.setAttribute('aria-pressed', 'false');
        element.style.removeProperty('width');
        element.style.removeProperty('height');
      }

      this.dragOriginSource = null;
      this.dragOriginNextSibling = null;
      this.draggedElement = null;
    }
  }

  private sortableIdentifier(item:HTMLElement) {
    const type = item.getAttribute('data-draggable-type') ?? 'item';
    const id = item.getAttribute('data-draggable-id') ?? item.id;

    return `${type}:${id}`;
  }

  private containerIdentifier(container:HTMLElement) {
    const targetId = container.getAttribute('data-target-id') ?? container.id;

    return `container:${targetId || this.containerTargets.indexOf(container)}`;
  }

  private isPlaceholderElement(element:Element|null|undefined):boolean {
    return element instanceof HTMLElement && element.hasAttribute('data-dnd-placeholder');
  }

  private realItemTargets() {
    return this.itemTargets.filter((item) => !this.isPlaceholderElement(item));
  }

  private realItemsInContainer(container:Element) {
    return this.realItemTargets().filter((item) => this.findContainerFor(item) === container);
  }

  private findContainerFor(item:Element) {
    let current = item.parentElement;

    while (current) {
      if (this.containerConfigs.has(current)) {
        return current;
      }

      current = current.parentElement;
    }

    return null;
  }

  private reindexItems() {
    const groups = new Map<HTMLElement, HTMLElement[]>();

    this.realItemTargets().forEach((item) => {
      const container = this.findContainerFor(item);
      if (!container) {
        return;
      }

      const items = groups.get(container) ?? [];
      items.push(item);
      groups.set(container, items);
    });

    groups.forEach((items) => {
      items.forEach((item, index) => {
        const sortable = this.sortables.get(item);
        if (sortable) {
          sortable.index = index;
        }
      });
    });
  }

  // Returns the data-draggable-id of the element preceding el in its container,
  // or null if el is the first item (signals "move to top").
  private resolveTargetPrevious(el:Element):string|null {
    let sibling = el.previousElementSibling;

    while (sibling) {
      if (!this.isPlaceholderElement(sibling)) {
        const id = sibling.getAttribute('data-draggable-id');
        if (id) {
          return id;
        }
      }

      sibling = sibling.previousElementSibling;
    }

    return null;
  }

  private resolveTargetPosition(el:Element, container:Element):number {
    const items = Array.from(container.children).filter((child) => (
      !this.isPlaceholderElement(child) && child.getAttribute('data-empty-list-item') !== 'true'
    ));

    return items.indexOf(el) + 1;
  }
}

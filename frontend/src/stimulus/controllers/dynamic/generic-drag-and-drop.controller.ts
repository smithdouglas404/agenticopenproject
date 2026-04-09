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
import type { DomAutoscrollService } from 'core-app/shared/helpers/drag-and-drop/dom-autoscroll.service';
import dragula, { Drake } from 'dragula';
import invariant from 'tiny-invariant';

interface TargetConfig {
  container:Element;
  allowedDragType:string|null;
  targetId:string|null;
}

export default class GenericDragAndDropController extends Controller {
  static targets = ['container', 'scrollContainer'];

  containerTargets:HTMLElement[];
  scrollContainerTargets:HTMLElement[];

  static values = {
    handleSelector: { type: String, default: '.DragHandle' },
    positionMode: { type: String, default: 'index' },
    // URL for bulk-moving multiple selected items in one request.
    // When empty, multi-drag falls back to sequential single-item moves.
    bulkDropUrl: { type: String, default: '' },
    // Enable multi-select interactions (Ctrl+Click, Shift+Click, Escape).
    multiSelect: { type: Boolean, default: false },
    // CSS class applied to selected items. Kept as a value so the controller
    // remains usable outside the backlogs context.
    selectedClass: { type: String, default: 'Box-row--blue' },
  };

  declare readonly handleSelectorValue:string;
  declare readonly positionModeValue:string;
  declare readonly bulkDropUrlValue:string;
  declare readonly multiSelectValue:boolean;
  declare readonly selectedClassValue:string;

  private drake:Drake|null = null;
  private autoscroll:DomAutoscrollService|null = null;
  private containers:HTMLElement[] = [];
  private targetConfigs:TargetConfig[] = [];
  private dragOriginSource:Element|null = null;
  private dragOriginNextSibling:Element|null = null;

  // Sibling selected items hidden during a multi-drag. Populated from selectedItems
  // at drag-start; emptied on drop or cancel. Length > 0 signals multi-drag is active.
  private multiDragSiblings:HTMLElement[] = [];
  private multiDragAllItems:HTMLElement[] = [];

  // Multi-selection state — only active when multiSelectValue is true.
  private selectedItems = new Set<HTMLElement>();
  private lastSelectedItem:HTMLElement|null = null;

  connect() {
    this.autoscroll?.destroy();
    this.drake?.destroy();
    this.initDrake();

    if (this.multiSelectValue) {
      // Capture phase so we intercept modifier-key clicks before other controllers can handle it
      this.element.addEventListener('click', this.onClickCapture, { capture: true });
      document.addEventListener('keydown', this.onKeydown);
    }
  }

  disconnect() {
    this.autoscroll?.destroy();
    this.autoscroll = null;
    this.drake?.destroy();
    this.drake = null;

    // Always attempt removal — no-op if the listeners were never added.
    this.element.removeEventListener('click', this.onClickCapture, { capture: true });
    document.removeEventListener('keydown', this.onKeydown);

    this.clearSelection();
  }

  containerTargetConnected(target:HTMLElement) {
    const container = this.resolveContainerElement(target);
    const targetConfig:TargetConfig = {
      container,
      allowedDragType: target.getAttribute('data-target-allowed-drag-type'),
      targetId: target.getAttribute('data-target-id'),
    };

    // we need to save the targetConfigs separately as we need to pass the pure container elements to drake
    // but need the configuration of the targets when dropping elements
    this.targetConfigs.push(targetConfig);
    this.containers.push(container);
  }

  containerTargetDisconnected(target:HTMLElement) {
    const container = this.resolveContainerElement(target);
    const index = this.containers.indexOf(container);
    if (index !== -1) {
      this.containers.splice(index, 1);
      this.targetConfigs.splice(index, 1);
    }

    // Drop stale selections when a container is removed (e.g. after turbo morph).
    // We delete directly from the Set rather than calling deselectItem() since the
    // elements are already detached and CSS manipulation would be a no-op anyway.
    this.selectedItems.forEach((item) => {
      if (!item.isConnected) this.selectedItems.delete(item);
    });
    if (this.lastSelectedItem && !this.lastSelectedItem.isConnected) {
      this.lastSelectedItem = null;
    }
  }

  cancelDrag() {
    this.drake?.cancel(true);
  }

  private onClickCapture = (event:MouseEvent):void => {
    const target = event.target as HTMLElement;
    const item = target.closest<HTMLElement>('[data-draggable-id]');
    if (!item) return;

    if (target.closest('a, button, clipboard-copy')) return;

    if (event.ctrlKey || event.metaKey) {
      event.stopPropagation();
      event.preventDefault();
      this.toggleSelect(item);
      return;
    }

    if (event.shiftKey) {
      event.stopPropagation();
      event.preventDefault();
      this.rangeSelect(item);
      return;
    }

    // Plain click: clear selection but do NOT stop propagation so StoryController
    // still receives the event and opens the split pane as normal.
    if (this.selectedItems.size > 0) this.clearSelection();
  };

  private onKeydown = (event:KeyboardEvent):void => {
    if (event.target instanceof HTMLElement
        && event.target.closest('input, textarea, select, [contenteditable="true"]')) return;

    if (event.key === 'Escape' && this.selectedItems.size > 0) this.clearSelection();
  };

  private toggleSelect(item:HTMLElement):void {
    if (this.selectedItems.has(item)) {
      this.deselectItem(item);
      if (this.lastSelectedItem === item) this.lastSelectedItem = null;
    } else {
      this.selectItem(item);
      this.lastSelectedItem = item;
    }
  }

  private rangeSelect(item:HTMLElement):void {
    const anchor = this.lastSelectedItem ?? item;
    const container = item.parentElement;

    if (!container || anchor.parentElement !== container) {
      // Anchor is in a different container — treat as a plain toggle.
      this.selectItem(item);
      this.lastSelectedItem = item;
      return;
    }

    const children = Array.from(container.children) as HTMLElement[];
    const fromIdx = children.indexOf(anchor);
    const toIdx = children.indexOf(item);
    const [start, end] = fromIdx <= toIdx ? [fromIdx, toIdx] : [toIdx, fromIdx];

    for (let i = start; i <= end; i++) {
      if (children[i].hasAttribute('data-draggable-id')) this.selectItem(children[i]);
    }
    this.lastSelectedItem = item;
  }

  private selectItem(item:HTMLElement):void {
    this.selectedItems.add(item);
    item.setAttribute('aria-selected', 'true');
    item.classList.add(this.selectedClassValue);
  }

  private deselectItem(item:HTMLElement):void {
    this.selectedItems.delete(item);
    item.removeAttribute('aria-selected');
    // Preserve the highlight class if the item is also the open split-pane entry.
    if (item.getAttribute('aria-current') !== 'true') {
      item.classList.remove(this.selectedClassValue);
    }
  }

  private clearSelection():void {
    this.selectedItems.forEach((item) => this.deselectItem(item));
    this.selectedItems.clear();
    this.lastSelectedItem = null;
  }

  initDrake() {
    // Note: dragula stores a reference to this.containers, so mutations
    // from containerTargetConnected/Disconnected automatically propagate.
    this.drake = dragula(
      this.containers,
      {
        moves: (_el, _source, handle, _sibling) => {
          if (!handle) return false;
          if (handle.closest('.DragHandle')) return true;
          const interactive = ['a', 'button', 'input', 'select', 'textarea'];
          if (interactive.some((sel) => handle.closest(sel) !== null)) return false;
          return !!handle.closest(this.handleSelectorValue);
        },
        accepts: (el:Element, target:Element, source:Element, sibling:Element) => this.accepts(el, target, source, sibling),
        revertOnSpill: true,
      },
    )
      .on('drag', (el:HTMLElement, source:HTMLElement) => {
        this.dragOriginSource = source;
        this.dragOriginNextSibling = el.nextElementSibling;

        el.querySelector(this.handleSelectorValue)?.setAttribute('aria-pressed', 'true');

        if (this.multiSelectValue && this.selectedItems.has(el)) {
          // Capture all selected items in original DOM order (including el).
          this.multiDragAllItems = [...this.selectedItems]
            .filter((item) => item.parentElement === source)
            .sort((a, b) => (a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1));
          this.multiDragSiblings = this.multiDragAllItems.filter((item) => item !== el);
          this.multiDragSiblings.forEach((item) => { item.style.visibility = 'hidden'; });
        } else {
          this.multiDragSiblings = [];
          this.multiDragAllItems = [];
        }
      })
      .on('cloned', (clone:HTMLElement, _original:HTMLElement, type:string) => {
        // Append a count badge to the drag mirror when moving multiple items.
        if (type === 'mirror' && this.multiDragSiblings.length > 0) {
          const badge = document.createElement('span');
          badge.className = 'op-backlogs-drag-count-badge';
          badge.setAttribute('aria-hidden', 'true');
          badge.textContent = String(this.multiDragSiblings.length + 1);
          clone.appendChild(badge);
        }
      })
      .on('dragend', (el:HTMLElement) => {
        el.querySelector(this.handleSelectorValue)?.setAttribute('aria-pressed', 'false');
        this.restoreMultiDragSiblings();
      })
      .on('cancel', () => {
        this.restoreMultiDragSiblings();
      })
      // eslint-disable-next-line @typescript-eslint/no-misused-promises
      .on('drop', this.drop.bind(this));

    // Setup autoscroll
    void window.OpenProject.getPluginContext().then((pluginContext) => {
      if (!this.element.isConnected) return;

      const scrollTargets:Element[] = this.scrollContainerTargets.length > 0
        ? this.scrollContainerTargets
        : [document.getElementById('content-body')!];

      this.autoscroll = new pluginContext.classes.DomAutoscrollService(
        scrollTargets,
        {
          margin: 25,
          maxSpeed: 10,
          scrollWhenOutside: true,
          autoScroll: () => this.drake?.dragging,
        },
      );
    });
  }

  accepts(el:Element, target:Element, _source:Element|null, _sibling:Element|null) {
    const targetConfig = this.targetConfigs.find((config) => config.container === target);
    const acceptedDragType = targetConfig?.allowedDragType as string|undefined;
    const draggableType = el.getAttribute('data-draggable-type');

    if (draggableType !== acceptedDragType) {
      debugLog('Element is not allowed to be dropped here');
      return false;
    }

    return true;
  }

  async drop(el:Element, target:Element, _source:Element|null, _sibling:Element|null) {
    if (this.multiDragSiblings.length > 0) {
      await this.dropMultiple(el, target);
    } else {
      await this.dropSingle(el, target);
    }
  }

  private async dropMultiple(el:Element, target:Element):Promise<void> {
    const elIdx = this.multiDragAllItems.indexOf(el as HTMLElement);
    const before = this.multiDragAllItems.slice(0, elIdx);
    const after = this.multiDragAllItems.slice(elIdx + 1);

    for (const item of before) {
      item.style.visibility = '';
      el.insertAdjacentElement('beforebegin', item);
    }
    let insertAfter:Element = el;
    for (const item of after) {
      item.style.visibility = '';
      insertAfter.insertAdjacentElement('afterend', item);
      insertAfter = item;
    }

    const allMovedItems = this.multiDragAllItems;
    this.multiDragSiblings = [];
    this.multiDragAllItems = [];

    const bulkDropUrl = this.bulkDropUrlValue;
    if (!bulkDropUrl) {
      for (const item of allMovedItems) {
        await this.dropSingle(item, target);
      }
      this.clearSelection();
      return;
    }

    try {
      const data = this.buildBulkData(allMovedItems, target);
      const request = new FetchRequest('put', bulkDropUrl, { body: data, responseKind: 'turbo-stream' });
      const response = await request.perform();

      if (!response.ok) {
        debugLog(`Failed to bulk-move items: ${response.statusCode}`);
        allMovedItems.forEach((item) => this.revertDrop(item));
      }
    } catch (error) {
      debugLog('Failed to bulk-move items due to request error', error);
      allMovedItems.forEach((item) => this.revertDrop(item));
    } finally {
      this.dragOriginSource = null;
      this.dragOriginNextSibling = null;
      // The turbo-stream morph will replace the DOM elements, so stale references
      // in selectedItems are cleaned up by containerTargetDisconnected. We also
      // clear here so the Set is immediately consistent.
      this.clearSelection();
    }
  }

  private async dropSingle(el:Element, target:Element):Promise<void> {
    const dropUrl = el.getAttribute('data-drop-url');
    const data = this.buildData(el, target);

    if (!dropUrl) return;

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
      this.dragOriginSource = null;
      this.dragOriginNextSibling = null;
    }
  }

  protected buildData(el:Element, target:Element):FormData {
    const data = new FormData();

    if (this.positionModeValue === 'prev_id') {
      data.append('prev_id', this.resolveTargetPrevious(el) ?? '');
    } else {
      data.append('position', this.resolveTargetPosition(el, target).toString());
    }

    const targetConfig = this.targetConfigs.find((config) => config.container === target);
    const targetId = targetConfig?.targetId as string|undefined;
    if (targetId) data.append('target_id', targetId.toString());

    return data;
  }

  // Always uses prev_id chaining for ordered positioning, regardless of positionModeValue.
  private buildBulkData(items:Element[], target:Element):FormData {
    const data = new FormData();

    items.forEach((item) => {
      const id = item.getAttribute('data-draggable-id');
      if (id) data.append('story_ids[]', id);
    });

    // prev_id = draggable-id of whatever now precedes the first moved item in the target
    const prevId = items[0].previousElementSibling?.getAttribute('data-draggable-id') ?? '';
    data.append('prev_id', prevId);

    const targetConfig = this.targetConfigs.find((config) => config.container === target);
    if (targetConfig?.targetId) data.append('target_id', targetConfig.targetId);

    return data;
  }

  private restoreMultiDragSiblings():void {
    this.multiDragSiblings.forEach((item) => { item.style.visibility = ''; });
    this.multiDragSiblings = [];
    this.multiDragAllItems = [];
  }

  private revertDrop(el:Element) {
    if (this.dragOriginSource) {
      if (this.dragOriginNextSibling?.parentNode === this.dragOriginSource) {
        this.dragOriginSource.insertBefore(el, this.dragOriginNextSibling);
      } else {
        this.dragOriginSource.appendChild(el);
      }
    }
  }

  // if the target has a container accessor, use that as the container instead of the element itself
  // we need this e.g. in Primer's borderbox component as we cannot add required data attributes to the ul element there
  private resolveContainerElement(target:HTMLElement):HTMLElement {
    const accessor = target.getAttribute('data-target-container-accessor');
    if (!accessor) return target;

    const container = target.querySelector<HTMLElement>(accessor);
    invariant(container, `Expected container element matching "${accessor}"`);
    return container;
  }

  // Returns the data-draggable-id of the element preceding el in its container,
  // or null if el is the first item (signals "move to top").
  private resolveTargetPrevious(el:Element):string|null {
    return el.previousElementSibling?.getAttribute('data-draggable-id') ?? null;
  }

  private resolveTargetPosition(el:Element, container:Element):number {
    let targetPosition = Array.from(container.children).indexOf(el);

    if (container.children.length > 0 && container.children[0].getAttribute('data-empty-list-item') === 'true') {
      // if the target container is empty, a list item showing an empty message might be shown
      // this should not be counted as a list item
      // thus we need to subtract 1 from the target position
      targetPosition -= 1;
    }

    return targetPosition + 1;
  }
}

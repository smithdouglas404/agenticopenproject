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
import { combine } from '@atlaskit/pragmatic-drag-and-drop/combine';
import { draggable, dropTargetForElements, monitorForElements } from '@atlaskit/pragmatic-drag-and-drop/element/adapter';
import { debugLog } from 'core-app/shared/helpers/debug_output';
import type { DomAutoscrollService } from 'core-app/shared/helpers/drag-and-drop/dom-autoscroll.service';
import invariant from 'tiny-invariant';
import type { CleanupFn } from '@atlaskit/pragmatic-drag-and-drop/types';


interface TargetConfig {
  container:HTMLElement;
  allowedDragType:string|null;
  targetId:string|null;
}

type ClosestEdge = 'before'|'after';

interface ContainerDropTargetData {
  kind:'container';
  container:HTMLElement;
}

interface DraggableDropTargetData {
  kind:'draggable';
  container:HTMLElement;
  closestEdge:ClosestEdge;
}

type DropTargetData = ContainerDropTargetData|DraggableDropTargetData;

interface DropDestination {
  element:Element;
  data:Record<string, unknown>;
}

interface MonitorDropArgs {
  source:{ element:HTMLElement };
  location:{ current:{ dropTargets:DropDestination[] } };
}

export default class GenericDragAndDropController extends Controller {
  static targets = [
    'container',
    'scrollContainer',
    'draggable',
  ];

  containerTargets:HTMLElement[];
  scrollContainerTargets:HTMLElement[];

  static values = {
    handleSelector: { type: String, default: '.DragHandle' },
    positionMode: { type: String, default: 'index' },
  };

  declare readonly handleSelectorValue:string;
  declare readonly positionModeValue:string;

  private autoscroll:DomAutoscrollService|null = null;
  private isDragging = false;
  private currentDragElement:HTMLElement|null = null;
  private monitorCleanup:CleanupFn|null = null;
  private dropTargetCleanups = new Map<HTMLElement, CleanupFn>();
  private draggableCleanups = new Map<HTMLElement, CleanupFn>();
  private containerConfigs = new Map<HTMLElement, TargetConfig>();
  private dragOriginSource:Element|null = null;
  private dragOriginNextSibling:Element|null = null;

  connect() {
    this.monitorCleanup?.();
    this.monitorCleanup = monitorForElements({
      onDrop: (args) => {
        void this.handleMonitorDrop(args as MonitorDropArgs);
      },
    });

    this.initAutoscroll();
  }

  disconnect() {
    this.monitorCleanup?.();
    this.monitorCleanup = null;

    this.autoscroll?.destroy();
    this.autoscroll = null;

    this.cleanupRegistrations();
    this.clearDragState();
  }

  containerTargetConnected(target:HTMLElement) {
    const container = this.resolveContainerElement(target);
    if (this.dropTargetCleanups.has(container)) {
      return;
    }

    const targetConfig:TargetConfig = {
      container,
      allowedDragType: target.getAttribute('data-target-allowed-drag-type'),
      targetId: target.getAttribute('data-target-id'),
    };

    const cleanup = dropTargetForElements({
      element: container,
      canDrop: ({ source }) => this.accepts(source.element, container),
      getData: () => ({
        kind: 'container',
        container,
      } satisfies ContainerDropTargetData),
    });

    this.containerConfigs.set(container, targetConfig);
    this.dropTargetCleanups.set(container, cleanup);
  }

  containerTargetDisconnected(target:HTMLElement) {
    const container = this.resolveContainerElement(target);

    this.dropTargetCleanups.get(container)?.();
    this.dropTargetCleanups.delete(container);
    this.containerConfigs.delete(container);
  }

  draggableTargetConnected(target:HTMLElement) {
    if (this.draggableCleanups.has(target) || this.dropTargetCleanups.has(target)) {
      return;
    }

    const container = this.findContainerForDraggable(target);
    if (!container) {
      queueMicrotask(() => {
        if (target.isConnected && !this.draggableCleanups.has(target)) {
          this.draggableTargetConnected(target);
        }
      });

      return;
    }

    const cleanup = combine(
      draggable({
        element: target,
        dragHandle: target.querySelector(this.handleSelectorValue) ?? undefined,
        canDrag: () => true,
        getInitialData: () => ({
          draggableType: target.getAttribute('data-draggable-type'),
        }),
        onDragStart: () => {
          this.isDragging = true;
          this.currentDragElement = target;
          this.dragOriginSource = target.parentElement;
          this.dragOriginNextSibling = target.nextElementSibling;
          this.setHandlePressed(target, true);
        },
        onDrop: () => {
          this.isDragging = false;
          this.setHandlePressed(target, false);
        },
      }),
      dropTargetForElements({
        element: target,
        canDrop: ({ source }) => source.element !== target && this.accepts(source.element, container),
        getData: ({ input, element }) => ({
          kind: 'draggable',
          container,
          closestEdge: this.getClosestEdge(input.clientY, element as HTMLElement),
        } satisfies DraggableDropTargetData),
      }),
    );

    this.draggableCleanups.set(target, cleanup);
    this.dropTargetCleanups.set(target, cleanup);
  }

  draggableTargetDisconnected(target:HTMLElement) {
    const cleanup = this.draggableCleanups.get(target);
    cleanup?.();

    this.draggableCleanups.delete(target);
    this.dropTargetCleanups.delete(target);
  }

  cancelDrag() {
    if (this.currentDragElement) {
      this.revertDrop(this.currentDragElement);
      this.clearDragState();
    }
  }

  accepts(el:Element, target:HTMLElement) {
    const targetConfig = this.containerConfigs.get(target);
    const acceptedDragType = targetConfig?.allowedDragType as string|undefined;
    const draggableType = el.getAttribute('data-draggable-type');

    if (draggableType !== acceptedDragType) {
      debugLog('Element is not allowed to be dropped here');
      return false;
    }

    return true;
  }

  async drop(el:Element, target:Element, _source:Element|null, _sibling:Element|null) {
    const dropUrl = el.getAttribute('data-drop-url');
    const data = this.buildData(el, target);

    if (!dropUrl) {
      this.clearDragState();
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
      this.clearDragState();
    }
  }

  protected buildData(el:Element, target:Element):FormData {
    const data = new FormData();

    if (this.positionModeValue === 'prev_id') {
      data.append('prev_id', this.resolveTargetPrevious(el) ?? '');
    } else {
      data.append('position', this.resolveTargetPosition(el, target).toString());
    }

    const targetConfig = this.containerConfigs.get(target as HTMLElement);
    const targetId = targetConfig?.targetId as string|undefined;

    if (targetId) {
      data.append('target_id', targetId.toString());
    }

    return data;
  }

  private cleanupRegistrations() {
    const cleanups = new Set([
      ...this.dropTargetCleanups.values(),
      ...this.draggableCleanups.values(),
    ]);

    cleanups.forEach((cleanup) => cleanup());
    this.dropTargetCleanups.clear();
    this.draggableCleanups.clear();
    this.containerConfigs.clear();
  }

  private clearDragState() {
    this.isDragging = false;
    this.currentDragElement = null;
    this.dragOriginSource = null;
    this.dragOriginNextSibling = null;
  }

  private setHandlePressed(target:Element, pressed:boolean) {
    const handle = target.querySelector(this.handleSelectorValue);
    handle?.setAttribute('aria-pressed', pressed ? 'true' : 'false');
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

  private initAutoscroll() {
    this.autoscroll?.destroy();

    void window.OpenProject.getPluginContext().then((pluginContext) => {
      if (!this.element.isConnected) {
        return;
      }

      const defaultScrollTarget = document.getElementById('content-body');
      const scrollTargets:Element[] = this.scrollContainerTargets.length > 0
        ? this.scrollContainerTargets
        : defaultScrollTarget ? [defaultScrollTarget] : [];

      this.autoscroll = new pluginContext.classes.DomAutoscrollService(
        scrollTargets,
        {
          margin: 25,
          maxSpeed: 10,
          scrollWhenOutside: true,
          autoScroll: () => this.isDragging,
        },
      );
    });
  }

  private async handleMonitorDrop({
    source,
    location,
  }:MonitorDropArgs) {
    const destination = location.current.dropTargets[0];
    if (!destination) {
      this.clearDragState();
      return;
    }

    const target = this.resolveDropContainer(destination.data as Partial<DropTargetData>);
    if (!target) {
      this.clearDragState();
      return;
    }

    this.moveElement(source.element, destination, target);
    await this.drop(source.element, target, this.dragOriginSource, this.dragOriginNextSibling);
  }

  private resolveDropContainer(data:Partial<DropTargetData>):HTMLElement|null {
    return data.container instanceof HTMLElement ? data.container : null;
  }

  private moveElement(sourceElement:HTMLElement, destination:DropDestination, target:HTMLElement) {
    const data = destination.data as Partial<DropTargetData>;

    if (data.kind === 'draggable') {
      const destinationElement = destination.element as HTMLElement;
      const insertionPoint = data.closestEdge === 'before' ? destinationElement : destinationElement.nextElementSibling;
      target.insertBefore(sourceElement, insertionPoint);
      return;
    }

    const emptyListItem = target.querySelector<HTMLElement>(':scope > [data-empty-list-item="true"]');
    if (emptyListItem) {
      target.insertBefore(sourceElement, emptyListItem);
    } else {
      target.appendChild(sourceElement);
    }
  }

  private getClosestEdge(clientY:number, element:HTMLElement):ClosestEdge {
    const { top, height } = element.getBoundingClientRect();
    const midpoint = top + (height / 2);

    return clientY < midpoint ? 'before' : 'after';
  }

  // if the target has a container accessor, use that as the container instead of the element itself
  // we need this e.g. in Primer's borderbox component as we cannot add required data attributes to the ul element there
  private resolveContainerElement(target:HTMLElement):HTMLElement {
    const accessor = target.getAttribute('data-target-container-accessor');
    if (!accessor) {
      return target;
    }

    const container = target.querySelector<HTMLElement>(accessor);
    invariant(container, `Expected container element matching "${accessor}"`);

    return container;
  }

  private findContainerForDraggable(target:HTMLElement):HTMLElement|null {
    let current:HTMLElement|null = target.parentElement;
    while (current) {
      if (this.containerConfigs.has(current)) {
        return current;
      }

      current = current.parentElement;
    }

    return null;
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

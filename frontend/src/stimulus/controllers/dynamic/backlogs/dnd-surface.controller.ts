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
import { debugLog, whenDebugging } from 'core-app/shared/helpers/debug_output';
import { sanitizeDndPlaceholder } from 'core-app/shared/helpers/drag-and-drop/dnd-placeholder-sanitizer';
import {
  AutoScroller,
  BeforeDragStartEvent,
  DragDropManager,
  DragEndEvent,
  Feedback,
  PointerActivationConstraints,
  PointerSensor,
  Droppable,
} from '@dnd-kit/dom';
import { Sortable } from '@dnd-kit/dom/sortable';
import DndListController from './dnd-list.controller';

interface DragOrigin {
  parent:HTMLElement;
  nextSibling:ChildNode|null;
}

interface ListMetadata {
  element:HTMLElement;
  itemContainer:HTMLElement;
  targetId:string;
  draggableItems:HTMLElement[];
}

interface SyncRegistrationsStats {
  calls:number;
  skippedWhileDragging:number;
  lastReason:string|null;
  lastMutationCount:number;
  lastListCount:number;
  lastItemCount:number;
  lastDurationMs:number;
}

interface SyncRegistrationsDetail {
  calls:number;
  durationMs:number;
  itemCount:number;
  listCount:number;
  mutationCount:number;
  reason:string;
  skippedWhileDragging:number;
}

declare global {
  interface Window {
    opBacklogsDndSurfaceDebug?:{
      syncRegistrations:SyncRegistrationsStats;
    };
  }
}

export default class DndSurfaceController extends Controller<HTMLElement> {
  static outlets = ['backlogs--dnd-list'];

  static values = {
    positionMode: String,
  };

  declare readonly backlogsDndListOutlets:DndListController[];
  declare readonly positionModeValue:string;

  manager:DragDropManager|null = null;
  readonly mutationObserver:MutationObserver|null = null;
  outletSyncsEnabled = false;

  private managerCleanupCallbacks:(() => void)[] = [];
  private registrationCleanupCallbacks:(() => void)[] = [];
  private dragOrigin:DragOrigin|null = null;
  private activeDragSource:HTMLElement|null = null;
  private readonly onListChanged = (event:Event):void => {
    if (!(event.target instanceof Element)) return;
    if (!this.resolveListControllerForElement(event.target)) return;

    this.syncRegistrations({ reason: 'list-changed' });
  };

  connect():void {
    this.outletSyncsEnabled = false;
    this.manager = this.createManager();
    this.bindManagerEvents();
    this.element.addEventListener('backlogs:dnd-list:changed', this.onListChanged);
    this.syncRegistrations({ reason: 'connect' });
    queueMicrotask(() => {
      this.outletSyncsEnabled = this.manager !== null;
    });
  }

  disconnect():void {
    this.outletSyncsEnabled = false;
    this.element.removeEventListener('backlogs:dnd-list:changed', this.onListChanged);
    this.managerCleanupCallbacks.forEach((cleanup) => cleanup());
    this.managerCleanupCallbacks = [];
    this.registrationCleanupCallbacks.forEach((cleanup) => cleanup());
    this.registrationCleanupCallbacks = [];
    this.manager?.destroy();
    this.manager = null;
    this.dragOrigin = null;
    this.activeDragSource = null;
  }

  backlogsDndListOutletConnected():void {
    if (!this.manager) return;
    if (!this.outletSyncsEnabled) return;

    this.syncRegistrations({ reason: 'outlet-connected' });
  }

  backlogsDndListOutletDisconnected():void {
    if (!this.manager) return;
    if (!this.outletSyncsEnabled) return;

    this.syncRegistrations({ reason: 'outlet-disconnected' });
  }

  private createManager():DragDropManager {
    return new DragDropManager({
      plugins: (defaults) => [
        ...defaults,
        Feedback.configure({ feedback: 'default', dropAnimation: null }),
        AutoScroller.configure({ acceleration: 25, threshold: 0.2 }),
      ],
      sensors: [
        PointerSensor.configure({
          activationConstraints: (event, source) => this.activationConstraintsFor(event, source.element),
        }),
      ],
    });
  }

  private bindManagerEvents():void {
    const manager = this.manager;
    if (!manager) return;

    this.managerCleanupCallbacks.push(
      manager.monitor.addEventListener('beforedragstart', (event) => this.onBeforeDragStart(event)),
      manager.monitor.addEventListener('dragend', (event) => {
        void this.onDragEnd(event);
      }),
    );
  }

  private syncRegistrations({ reason, mutationCount = 0 }:{ reason:string; mutationCount?:number }):void {
    if (this.activeDragSource && reason !== 'drag-end') {
      sanitizeDndPlaceholder(this.activeDragSource, this.element);
      this.recordSkippedSync({ reason, mutationCount });
      return;
    }

    const startedAt = performance.now();

    this.registrationCleanupCallbacks.forEach((cleanup) => cleanup());
    this.registrationCleanupCallbacks = [];

    const manager = this.manager;
    if (!manager) return;

    const lists = this.listMetadatas();
    let itemCount = 0;

    lists.forEach((list) => {
      const shell = new Droppable({
        id: list.targetId,
        element: list.element,
        type: 'story',
        accept: 'story',
      }, manager);

      this.registrationCleanupCallbacks.push(shell.register() ?? (() => undefined));

      itemCount += list.draggableItems.length;

      list.draggableItems.forEach((item, index) => {
        const sortable = new Sortable({
          id: this.draggableIdFor(item),
          element: item,
          index,
          group: list.targetId,
          type: 'story',
        }, manager);

        this.registrationCleanupCallbacks.push(sortable.register() ?? (() => undefined));
      });
    });

    this.recordSyncTelemetry({
      reason,
      mutationCount,
      listCount: lists.length,
      itemCount,
      durationMs: performance.now() - startedAt,
    });
  }

  private listMetadatas():ListMetadata[] {
    return this.backlogsDndListOutlets
      .map((outlet) => ({
        element: outlet.dropZoneElement,
        itemContainer: outlet.itemContainer,
        targetId: outlet.targetId,
        draggableItems: outlet.draggableItems,
      }))
      .filter((list) => list.targetId.length > 0);
  }

  private draggableIdFor(element:HTMLElement):string {
    return element.getAttribute('data-draggable-id') ?? '';
  }

  private onBeforeDragStart(event:BeforeDragStartEvent|{ operation:{ source:{ element?:Element|null }|null } }):void {
    const sourceElement = event.operation.source?.element;
    if (!(sourceElement instanceof HTMLElement) || !(sourceElement.parentElement instanceof HTMLElement)) return;

    this.activeDragSource = sourceElement;
    this.dragOrigin = {
      parent: sourceElement.parentElement,
      nextSibling: sourceElement.nextSibling,
    };
  }

  private async onDragEnd(event:DragEndEvent|{ canceled:boolean; operation:{ source:{ element?:Element|null }|null; target?:{ element?:Element|null }|null } }):Promise<void> {
    const sourceElement = event.operation.source?.element;

    if (!(sourceElement instanceof HTMLElement)) {
      this.clearDragState();
      return;
    }

    if (event.canceled) {
      this.revertMove(sourceElement);
      this.clearDragState();
      return;
    }

    this.applyListLevelDrop(sourceElement, event.operation.target?.element ?? null);

    const targetList = this.resolveListForElement(sourceElement);
    const dropUrl = sourceElement.getAttribute('data-drop-url');

    if (!targetList || !dropUrl) {
      this.revertMove(sourceElement);
      this.clearDragState();
      return;
    }

    const succeeded = await this.persistMove(dropUrl, this.buildMoveData(sourceElement, targetList.targetId));

    if (!succeeded) {
      this.revertMove(sourceElement);
    }

    this.clearDragState();
    queueMicrotask(() => this.syncRegistrations({ reason: 'drag-end' }));
  }

  private clearDragState():void {
    this.dragOrigin = null;
    this.activeDragSource = null;
  }

  private applyListLevelDrop(sourceElement:HTMLElement, targetElement:Element|null):void {
    if (!(targetElement instanceof HTMLElement)) return;

    const targetList = this.resolveListForElement(targetElement);
    if (!targetList) return;

    if (sourceElement.parentElement !== targetList.itemContainer) {
      targetList.itemContainer.appendChild(sourceElement);
    }
  }

  private resolveListForElement(element:Element):ListMetadata|null {
    const outlet = this.resolveListControllerForElement(element);
    if (!outlet) return null;

    return {
      element: outlet.dropZoneElement,
      itemContainer: outlet.itemContainer,
      targetId: outlet.targetId,
      draggableItems: outlet.draggableItems,
    };
  }

  private buildMoveData(sourceElement:HTMLElement, targetId:string):FormData {
    const data = new FormData();
    data.append('target_id', targetId);
    data.append('prev_id', this.previousDraggableId(sourceElement) ?? '');
    return data;
  }

  private previousDraggableId(sourceElement:HTMLElement):string|null {
    let sibling = sourceElement.previousElementSibling;

    while (sibling instanceof HTMLElement) {
      const draggableId = sibling.getAttribute('data-draggable-id');
      if (draggableId) {
        return draggableId;
      }
      sibling = sibling.previousElementSibling;
    }

    return null;
  }

  private revertMove(sourceElement:HTMLElement):void {
    if (!this.dragOrigin) return;

    const { parent, nextSibling } = this.dragOrigin;
    parent.insertBefore(sourceElement, nextSibling);
  }

  private async persistMove(dropUrl:string, data:FormData):Promise<boolean> {
    try {
      const request = new FetchRequest('put', dropUrl, { body: data, responseKind: 'turbo-stream' });
      const response = await request.perform();
      return response.ok;
    } catch {
      return false;
    }
  }

  private activationConstraintsFor(event:{ pointerType?:string; target?:EventTarget|null }, sourceElement?:Element|null) {
    if (event.pointerType === 'touch') {
      return [new PointerActivationConstraints.Delay({ value: 250, tolerance: 5 })];
    }

    if (event.target === sourceElement) {
      return [new PointerActivationConstraints.Distance({ value: 5 })];
    }

    return [
      new PointerActivationConstraints.Delay({ value: 200, tolerance: 10 }),
      new PointerActivationConstraints.Distance({ value: 5 }),
    ];
  }

  private recordSkippedSync({ reason, mutationCount }:{ reason:string; mutationCount:number }):void {
    whenDebugging(() => {
      const syncStats = this.ensureDebugStats();
      syncStats.skippedWhileDragging += 1;
      syncStats.lastReason = `${reason}-skipped-during-drag`;
      syncStats.lastMutationCount = mutationCount;

      debugLog('Backlogs DnD skipped registration sync during active drag', {
        mutationCount,
        skippedWhileDragging: syncStats.skippedWhileDragging,
      });
    });
  }

  private recordSyncTelemetry({ reason, mutationCount, listCount, itemCount, durationMs }:Omit<SyncRegistrationsDetail, 'calls'|'skippedWhileDragging'>):void {
    whenDebugging(() => {
      const syncStats = this.ensureDebugStats();
      syncStats.calls += 1;
      syncStats.lastReason = reason;
      syncStats.lastMutationCount = mutationCount;
      syncStats.lastListCount = listCount;
      syncStats.lastItemCount = itemCount;
      syncStats.lastDurationMs = durationMs;

      const detail:SyncRegistrationsDetail = {
        calls: syncStats.calls,
        durationMs,
        itemCount,
        listCount,
        mutationCount,
        reason,
        skippedWhileDragging: syncStats.skippedWhileDragging,
      };

      debugLog('Backlogs DnD syncRegistrations', detail);
      document.dispatchEvent(new CustomEvent<SyncRegistrationsDetail>('backlogs:dnd-surface:sync-registrations', { detail }));
    });
  }

  private ensureDebugStats():SyncRegistrationsStats {
    window.opBacklogsDndSurfaceDebug ??= {
      syncRegistrations: {
        calls: 0,
        skippedWhileDragging: 0,
        lastReason: null,
        lastMutationCount: 0,
        lastListCount: 0,
        lastItemCount: 0,
        lastDurationMs: 0,
      },
    };

    return window.opBacklogsDndSurfaceDebug.syncRegistrations;
  }

  private resolveListControllerForElement(element:Element):DndListController|null {
    return this.backlogsDndListOutlets.find((outlet) => outlet.dropZoneElement.contains(element)) ?? null;
  }
}

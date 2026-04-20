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

export default class DndListController extends Controller<HTMLElement> {
  static targets = [
    'container',
    'item',
  ];

  static values = {
    targetId: String,
  };

  declare readonly containerTarget:HTMLElement;
  declare readonly itemTargets:HTMLElement[];
  declare readonly targetIdValue:string;

  private initialTargetSyncPending = true;
  private changeEventScheduled = false;
  private changeEventSequence = 0;

  get targetId():string {
    return this.targetIdValue;
  }

  get dropZoneElement():HTMLElement {
    return this.element;
  }

  get itemContainer():HTMLElement {
    return this.containerTarget;
  }

  get draggableItems():HTMLElement[] {
    return this.itemTargets.filter((element) => this.isDraggableItem(element));
  }

  get isEmpty():boolean {
    return this.draggableItems.length === 0;
  }

  connect():void {
    this.initialTargetSyncPending = false;
  }

  disconnect():void {
    this.initialTargetSyncPending = true;
    this.changeEventScheduled = false;
    this.changeEventSequence += 1;
  }

  itemTargetConnected():void {
    this.emitChangeIfReady();
  }

  itemTargetDisconnected():void {
    this.emitChangeIfReady();
  }

  private emitChangeIfReady():void {
    if (this.initialTargetSyncPending) return;
    if (this.changeEventScheduled) return;

    const sequence = this.changeEventSequence;
    this.changeEventScheduled = true;

    queueMicrotask(() => {
      if (sequence !== this.changeEventSequence) return;

      this.changeEventScheduled = false;

      if (this.initialTargetSyncPending) return;

      this.element.dispatchEvent(new CustomEvent('backlogs:dnd-list:changed', {
        bubbles: true,
      }));
    });
  }

  private isDraggableItem(element:HTMLElement):boolean {
    return element.hasAttribute('data-draggable-id');
  }
}

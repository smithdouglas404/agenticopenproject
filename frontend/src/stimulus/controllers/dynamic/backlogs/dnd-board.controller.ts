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
import BacklogsDndItemController from './dnd-item.controller';
import BacklogsDndListController from './dnd-list.controller';
import { pragmaticDnd } from './pragmatic-dnd';

type DropKind = 'item'|'list';
type DropEdge = 'before'|'after';

interface DropDestination {
  element:Element;
  data:{
    kind?:DropKind;
    listId?:string;
    edge?:DropEdge;
  };
}

interface MonitorDropArgs {
  source:{
    element:HTMLElement;
    data:{
      itemType?:string;
    };
  };
  location:{ current:{ dropTargets:DropDestination[] } };
}

export default class BacklogsDndBoardController extends Controller<HTMLElement> {
  static outlets = ['backlogs--dnd-list', 'backlogs--dnd-item'];

  private monitorCleanup:(() => void)|null = null;
  private requestInFlight = false;
  private itemControllersByElement = new Map<HTMLElement, BacklogsDndItemController>();
  private listControllersByElement = new Map<HTMLElement, BacklogsDndListController>();

  connect() {
    this.monitorCleanup?.();
    this.monitorCleanup = pragmaticDnd.monitorForElements({
      canMonitor: ({ source }) => source.data.itemType === 'story',
      onDrop: (args) => {
        void this.handleMonitorDrop(args as MonitorDropArgs);
      },
    });
  }

  disconnect() {
    this.monitorCleanup?.();
    this.monitorCleanup = null;
  }

  backlogsDndItemOutletConnected(outlet:BacklogsDndItemController, element:HTMLElement) {
    this.itemControllersByElement.set(element, outlet);
  }

  backlogsDndItemOutletDisconnected(_outlet:BacklogsDndItemController, element:HTMLElement) {
    this.itemControllersByElement.delete(element);
  }

  backlogsDndListOutletConnected(outlet:BacklogsDndListController, element:HTMLElement) {
    this.listControllersByElement.set(element, outlet);
  }

  backlogsDndListOutletDisconnected(_outlet:BacklogsDndListController, element:HTMLElement) {
    this.listControllersByElement.delete(element);
  }

  async handleMonitorDrop({ source, location }:MonitorDropArgs) {
    if (this.requestInFlight) {
      return;
    }

    const sourceElement = source.element;
    const sourceItem = this.itemControllerFor(sourceElement);
    const destination = location.current.dropTargets[0];

    if (!sourceItem || !destination) {
      return;
    }

    if (destination.element === sourceElement) {
      return;
    }

    const destinationList = this.resolveDestinationList(destination);
    if (!destinationList) {
      return;
    }

    const originalParent = sourceElement.parentElement;
    const originalNextSibling = sourceElement.nextElementSibling;

    this.moveElement(sourceElement, destination, destinationList.element);

    const data = new FormData();
    data.append('target_id', destinationList.listIdValue);
    data.append('prev_id', this.previousItemId(sourceElement));

    this.setBusy(true);

    try {
      const request = new FetchRequest('put', sourceItem.dropUrlValue, { body: data, responseKind: 'turbo-stream' });
      const response = await request.perform();

      if (!response.ok) {
        this.revertMove(sourceElement, originalParent, originalNextSibling);
      }
    } catch {
      this.revertMove(sourceElement, originalParent, originalNextSibling);
    } finally {
      this.setBusy(false);
    }
  }

  private resolveDestinationList(destination:DropDestination):BacklogsDndListController|null {
    if (destination.data.kind === 'list' && destination.element instanceof HTMLElement) {
      return this.listControllerFor(destination.element);
    }

    if (destination.element instanceof HTMLElement) {
      const listElement = destination.element.closest<HTMLElement>('[data-controller~="backlogs--dnd-list"]');
      if (listElement) {
        return this.listControllerFor(listElement);
      }
    }

    return null;
  }

  private moveElement(sourceElement:HTMLElement, destination:DropDestination, destinationList:HTMLElement) {
    if (destination.data.kind === 'item' && destination.element instanceof HTMLElement) {
      const insertionPoint = destination.data.edge === 'after' ? destination.element.nextElementSibling : destination.element;
      destinationList.insertBefore(sourceElement, insertionPoint);
      return;
    }

    const emptyListPlaceholder = destinationList.querySelector<HTMLElement>('[data-empty-list-item]');
    if (emptyListPlaceholder) {
      destinationList.insertBefore(sourceElement, emptyListPlaceholder);
      return;
    }

    destinationList.appendChild(sourceElement);
  }

  private revertMove(sourceElement:HTMLElement, originalParent:Element|null, originalNextSibling:Element|null) {
    if (!originalParent) {
      return;
    }

    if (originalNextSibling?.parentElement === originalParent) {
      originalParent.insertBefore(sourceElement, originalNextSibling);
      return;
    }

    originalParent.appendChild(sourceElement);
  }

  private itemControllerFor(element:HTMLElement):BacklogsDndItemController|null {
    return this.itemControllersByElement.get(element) ?? null;
  }

  private listControllerFor(element:HTMLElement):BacklogsDndListController|null {
    return this.listControllersByElement.get(element) ?? null;
  }

  private previousItemId(element:HTMLElement):string {
    let sibling = element.previousElementSibling;

    while (sibling instanceof HTMLElement) {
      const siblingController = this.itemControllerFor(sibling);
      if (siblingController) {
        return siblingController.itemIdValue;
      }

      const previousItemId = sibling.getAttribute('data-backlogs--dnd-prev-id-value');
      if (previousItemId) {
        return previousItemId;
      }

      sibling = sibling.previousElementSibling;
    }

    return '';
  }

  private setBusy(isBusy:boolean) {
    this.requestInFlight = isBusy;
    this.element.classList.toggle('is-dnd-busy', isBusy);
    this.element.setAttribute('aria-busy', String(isBusy));
  }
}

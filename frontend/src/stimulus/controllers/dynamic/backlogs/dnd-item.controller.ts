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
import { pragmaticDnd } from './pragmatic-dnd';

export default class BacklogsDndItemController extends Controller<HTMLElement> {
  static values = {
    itemId: String,
    itemType: String,
    dropUrl: String,
  };

  declare readonly itemIdValue:string;
  declare readonly itemTypeValue:string;
  declare readonly dropUrlValue:string;

  private cleanup:(() => void)|null = null;
  private abortController:AbortController|null = null;

  connect() {
    this.abortController?.abort();
    this.abortController = new AbortController();
    this.element.addEventListener('turbo:morph-element', this.refreshRegistration, { signal: this.abortController.signal });
    this.registerPragmaticDnd();
  }

  disconnect() {
    this.cleanup?.();
    this.cleanup = null;
    this.abortController?.abort();
    this.abortController = null;
  }

  private registerPragmaticDnd() {
    this.cleanup?.();
    this.cleanup = pragmaticDnd.combine(
      pragmaticDnd.draggable({
        element: this.element,
        getInitialData: () => ({
          itemId: this.itemIdValue,
          itemType: this.itemTypeValue,
        }),
      }),
      pragmaticDnd.dropTargetForElements({
        element: this.element,
        canDrop: () => true,
        getData: ({ input, element }) => ({
          kind: 'item',
          itemId: this.itemIdValue,
          edge: this.closestEdge(input.clientY, element as HTMLElement),
        }),
      }),
    );
  }

  private refreshRegistration = (event:Event) => {
    if (event.target !== this.element) {
      return;
    }

    this.registerPragmaticDnd();
  };

  private closestEdge(clientY:number, element:HTMLElement) {
    const { top, height } = element.getBoundingClientRect();
    const midpoint = top + (height / 2);

    return clientY < midpoint ? 'before' : 'after';
  }
}

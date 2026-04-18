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
/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-unsafe-assignment */

import GenericDragAndDropController from './generic-drag-and-drop.controller';

describe('GenericDragAndDropController', () => {
  let controller:any;

  beforeEach(() => {
    controller = Object.create(GenericDragAndDropController.prototype);
  });

  function createItem(id:string, container:HTMLElement) {
    const item = document.createElement('li');
    item.dataset.genericDragAndDropTarget = 'item';
    item.dataset.draggableId = id;
    container.appendChild(item);

    return item;
  }

  function createPlaceholder(container:HTMLElement) {
    const item = document.createElement('li');
    item.dataset.genericDragAndDropTarget = 'item';
    item.setAttribute('data-dnd-placeholder', '');
    container.appendChild(item);

    return item;
  }

  describe('resolveTargetPrevious', () => {
    it('skips placeholder siblings when deriving prev_id', () => {
      const container = document.createElement('ul');
      const previous = createItem('11', container);
      createPlaceholder(container);
      const current = createItem('22', container);

      expect(controller.resolveTargetPrevious(current)).toBe('11');
      expect(previous.dataset.draggableId).toBe('11');
    });
  });

  describe('resolveTargetPosition', () => {
    it('ignores placeholder items when deriving the 1-based position', () => {
      const container = document.createElement('ul');
      createItem('11', container);
      createPlaceholder(container);
      const current = createItem('22', container);

      expect(controller.resolveTargetPosition(current, container)).toBe(2);
    });
  });

  describe('reindexItems', () => {
    it('assigns sortable indexes per container and ignores placeholders', () => {
      const containerA = document.createElement('ul');
      const containerB = document.createElement('ul');

      const first = createItem('11', containerA);
      createPlaceholder(containerA);
      const second = createItem('22', containerA);
      const third = createItem('33', containerB);

      controller.itemTargets = [first, second, third];
      controller.sortables = new Map([
        [first, { index: -1 }],
        [second, { index: -1 }],
        [third, { index: -1 }],
      ]);
      controller.findContainerFor = (item:HTMLElement) => item.parentElement;

      controller.reindexItems();

      expect(controller.sortables.get(first).index).toBe(0);
      expect(controller.sortables.get(second).index).toBe(1);
      expect(controller.sortables.get(third).index).toBe(0);
    });
  });

  describe('onBeforeDragStart', () => {
    it('pins the dragged element dimensions before feedback rendering', () => {
      const container = document.createElement('ul');
      const item = createItem('22', container);
      const handle = document.createElement('button');
      handle.className = 'DragHandle';
      item.appendChild(handle);
      spyOn(item, 'getBoundingClientRect').and.returnValue({
        width: 420,
        height: 66,
      } as DOMRect);

      controller.handleSelectorValue = '.DragHandle';

      controller.onBeforeDragStart({
        operation: {
          source: {
            element: item,
          },
        },
      });

      expect(item.style.getPropertyValue('width')).toBe('420px');
      expect(item.style.getPropertyValue('height')).toBe('66px');
      expect(handle.getAttribute('aria-pressed')).toBe('true');
    });
  });
});

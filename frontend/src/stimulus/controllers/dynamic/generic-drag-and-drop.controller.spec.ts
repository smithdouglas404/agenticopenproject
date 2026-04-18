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

import { Application } from '@hotwired/stimulus';
import GenericDragAndDropController from './generic-drag-and-drop.controller';

const nextFrame = () => new Promise((resolve) => requestAnimationFrame(resolve));

describe('GenericDragAndDropController', () => {
  let Stimulus:Application;
  let fixturesElement:HTMLElement;

  beforeEach(() => {
    fixturesElement = document.createElement('div');
    document.body.appendChild(fixturesElement);
  });

  beforeEach(async () => {
    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('generic-drag-and-drop', GenericDragAndDropController);
    await nextFrame();
  });

  afterEach(() => {
    fixturesElement.remove();
    Stimulus.stop();
  });

  function appendTemplate(html:string) {
    const template = document.createElement('template');
    template.innerHTML = html.trim();
    fixturesElement.appendChild(template.content.cloneNode(true));
  }

  it('pins dragged element dimensions during beforedragstart', async () => {
    appendTemplate(`
      <div data-controller="generic-drag-and-drop">
        <ul
          data-generic-drag-and-drop-target="container"
          data-target-allowed-drag-type="story"
        >
          <li
            id="story-1"
            data-generic-drag-and-drop-target="item"
            data-draggable-id="1"
            data-draggable-type="story"
            data-drop-url="/work_packages/1/move"
          >
            <div class="DragHandle" aria-pressed="false"></div>
          </li>
          <li
            id="story-2"
            data-generic-drag-and-drop-target="item"
            data-draggable-id="2"
            data-draggable-type="story"
            data-drop-url="/work_packages/2/move"
          >
            <div class="DragHandle" aria-pressed="false"></div>
          </li>
        </ul>
      </div>
    `);
    await nextFrame();

    const root = document.querySelector<HTMLElement>('[data-controller="generic-drag-and-drop"]')!;
    const controller = Stimulus.getControllerForElementAndIdentifier(
      root,
      'generic-drag-and-drop',
    ) as GenericDragAndDropController;
    const firstItem = document.getElementById('story-1')!;
    const handle = firstItem.querySelector<HTMLElement>('.DragHandle')!;

    spyOn(firstItem, 'getBoundingClientRect').and.returnValue({
      width: 320,
      height: 64,
      top: 0,
      right: 320,
      bottom: 64,
      left: 0,
      x: 0,
      y: 0,
      toJSON: () => ({}),
    } as DOMRect);

    (controller as unknown as {
      onBeforeDragStart:(event:{ operation:{ source:{ element:HTMLElement } } }) => void;
    }).onBeforeDragStart({
      operation: {
        source: {
          element: firstItem,
        },
      },
    });

    expect(firstItem.style.getPropertyValue('width')).toBe('320px');
    expect(firstItem.style.getPropertyPriority('width')).toBe('important');
    expect(firstItem.style.getPropertyValue('height')).toBe('64px');
    expect(firstItem.style.getPropertyPriority('height')).toBe('important');
    expect(handle.getAttribute('aria-pressed')).toBe('true');
    expect((controller as unknown as { draggedElement:HTMLElement|null }).draggedElement).toBe(firstItem);
    expect((controller as unknown as { dragOriginSource:Element|null }).dragOriginSource).toBe(firstItem.parentElement);
    expect((controller as unknown as { dragOriginNextSibling:Element|null }).dragOriginNextSibling)
      .toBe(document.getElementById('story-2'));
  });

  it('ignores dnd-kit placeholder clones when they connect as item targets', async () => {
    appendTemplate(`
      <div data-controller="generic-drag-and-drop">
        <ul
          data-generic-drag-and-drop-target="container"
          data-target-allowed-drag-type="story"
        >
          <li
            id="story-1"
            data-generic-drag-and-drop-target="item"
            data-draggable-id="1"
            data-draggable-type="story"
            data-drop-url="/work_packages/1/move"
          >
            <div class="DragHandle" aria-pressed="false"></div>
          </li>
        </ul>
      </div>
    `);
    await nextFrame();

    const root = document.querySelector<HTMLElement>('[data-controller="generic-drag-and-drop"]')!;
    const controller = Stimulus.getControllerForElementAndIdentifier(
      root,
      'generic-drag-and-drop',
    ) as GenericDragAndDropController;
    const original = document.getElementById('story-1')!;
    const placeholder = original.cloneNode(true) as HTMLElement;

    placeholder.setAttribute('data-dnd-placeholder', 'hidden');
    original.insertAdjacentElement('afterend', placeholder);

    (controller as unknown as { itemTargetConnected:(item:HTMLElement) => void }).itemTargetConnected(placeholder);

    expect((controller as unknown as { sortables:Map<HTMLElement, unknown> }).sortables.size).toBe(1);
    expect((controller as unknown as { sortables:Map<HTMLElement, unknown> }).sortables.has(placeholder)).toBeFalse();
  });
});

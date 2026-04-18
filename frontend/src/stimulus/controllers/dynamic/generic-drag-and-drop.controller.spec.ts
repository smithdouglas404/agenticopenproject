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
    expect(firstItem.hasAttribute('data-generic-dnd-preview-active')).toBeTrue();
    expect(handle.getAttribute('aria-pressed')).toBe('true');
    expect((controller as unknown as { draggedElement:HTMLElement|null }).draggedElement).toBe(firstItem);
    expect((controller as unknown as { dragOriginSource:Element|null }).dragOriginSource).toBe(firstItem.parentElement);
    expect((controller as unknown as { dragOriginNextSibling:Element|null }).dragOriginNextSibling)
      .toBe(document.getElementById('story-2'));
  });

  it('clears the temporary preview marker after dragend cleanup', async () => {
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
            <div class="DragHandle" aria-pressed="true"></div>
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

    firstItem.setAttribute('data-generic-dnd-preview-active', '');
    firstItem.style.setProperty('width', '320px', 'important');
    firstItem.style.setProperty('height', '64px', 'important');
    (controller as unknown as { draggedElement:HTMLElement|null }).draggedElement = firstItem;
    spyOn(controller, 'drop').and.resolveTo();

    await (controller as unknown as {
      onDragEnd:(event:{ canceled:boolean }) => Promise<void>;
    }).onDragEnd({ canceled: false });

    expect(firstItem.hasAttribute('data-generic-dnd-preview-active')).toBeFalse();
    expect(firstItem.style.getPropertyValue('width')).toBe('');
    expect(firstItem.style.getPropertyValue('height')).toBe('');
    expect(firstItem.querySelector('.DragHandle')?.getAttribute('aria-pressed')).toBe('false');
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

  it('re-registers meetings subclass targets on turbo morph events', async () => {
    Stimulus.stop();
    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('meetings--drag-and-drop', GenericDragAndDropController);

    appendTemplate(`
      <div data-controller="meetings--drag-and-drop">
        <ul
          data-meetings--drag-and-drop-target="container"
          data-target-allowed-drag-type="agenda-item"
        >
          <li
            id="agenda-1"
            data-meetings--drag-and-drop-target="item"
            data-draggable-id="1"
            data-draggable-type="agenda-item"
            data-drop-url="/meetings/1/agenda_items/1/drop"
          >
            <div class="DragHandle" aria-pressed="false"></div>
          </li>
        </ul>
      </div>
    `);
    await nextFrame();

    const root = document.querySelector<HTMLElement>('[data-controller="meetings--drag-and-drop"]')!;
    const controller = Stimulus.getControllerForElementAndIdentifier(
      root,
      'meetings--drag-and-drop',
    ) as GenericDragAndDropController;
    const item = document.getElementById('agenda-1')!;
    const connectSpy = spyOn(
      controller as unknown as { itemTargetConnected:(item:HTMLElement) => void },
      'itemTargetConnected',
    ).and.callThrough();

    item.dispatchEvent(new CustomEvent('turbo:morph-element', { bubbles: true }));

    expect(connectSpy).toHaveBeenCalledWith(item);
  });

  it('refreshes an item sortable when Turbo replaces descendants inside the item', async () => {
    Stimulus.stop();
    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('meetings--drag-and-drop', GenericDragAndDropController);

    appendTemplate(`
      <div data-controller="meetings--drag-and-drop">
        <div
          id="sections"
          data-meetings--drag-and-drop-target="container"
          data-target-allowed-drag-type="section"
        >
          <section
            id="section-1"
            data-meetings--drag-and-drop-target="item"
            data-draggable-id="section-1"
            data-draggable-type="section"
            data-drop-url="/meetings/1/sections/1/drop"
          >
            <div class="DragHandle" aria-pressed="false"></div>
            <span id="label">Section 1</span>
          </section>
        </div>
      </div>
    `);
    await nextFrame();

    const root = document.querySelector<HTMLElement>('[data-controller="meetings--drag-and-drop"]')!;
    const controller = Stimulus.getControllerForElementAndIdentifier(
      root,
      'meetings--drag-and-drop',
    ) as GenericDragAndDropController;
    const item = document.getElementById('section-1')!;
    const connectSpy = spyOn(
      controller as unknown as { itemTargetConnected:(target:HTMLElement) => void },
      'itemTargetConnected',
    ).and.callThrough();

    item.querySelector('.DragHandle')?.remove();
    item.insertAdjacentHTML('afterbegin', '<div class="DragHandle" aria-pressed="false"></div>');
    await nextFrame();

    expect(connectSpy).toHaveBeenCalledWith(item);
  });

  it('uses the nearest registered container and per-container indexes for nested meetings items', async () => {
    Stimulus.stop();
    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('meetings--drag-and-drop', GenericDragAndDropController);

    appendTemplate(`
      <div data-controller="meetings--drag-and-drop">
        <div
          id="sections"
          data-meetings--drag-and-drop-target="container"
          data-target-allowed-drag-type="section"
        >
          <section
            id="section-1"
            data-meetings--drag-and-drop-target="item"
            data-draggable-id="section-1"
            data-draggable-type="section"
            data-drop-url="/meetings/1/sections/1/drop"
          >
            <div class="DragHandle" aria-pressed="false"></div>
            <ul
              id="agenda-list-1"
              data-meetings--drag-and-drop-target="container"
              data-target-allowed-drag-type="agenda-item"
              data-target-id="1"
            >
              <li
                id="agenda-1"
                data-meetings--drag-and-drop-target="item"
                data-draggable-id="1"
                data-draggable-type="agenda-item"
                data-drop-url="/meetings/1/agenda_items/1/drop"
              >
                <div class="DragHandle" aria-pressed="false"></div>
              </li>
              <li
                id="agenda-2"
                data-meetings--drag-and-drop-target="item"
                data-draggable-id="2"
                data-draggable-type="agenda-item"
                data-drop-url="/meetings/1/agenda_items/2/drop"
              >
                <div class="DragHandle" aria-pressed="false"></div>
              </li>
            </ul>
          </section>
          <section
            id="section-2"
            data-meetings--drag-and-drop-target="item"
            data-draggable-id="section-2"
            data-draggable-type="section"
            data-drop-url="/meetings/1/sections/2/drop"
          >
            <div class="DragHandle" aria-pressed="false"></div>
            <ul
              id="agenda-list-2"
              data-meetings--drag-and-drop-target="container"
              data-target-allowed-drag-type="agenda-item"
              data-target-id="2"
            >
              <li
                id="agenda-3"
                data-meetings--drag-and-drop-target="item"
                data-draggable-id="3"
                data-draggable-type="agenda-item"
                data-drop-url="/meetings/1/agenda_items/3/drop"
              >
                <div class="DragHandle" aria-pressed="false"></div>
              </li>
            </ul>
          </section>
        </div>
      </div>
    `);
    await nextFrame();

    const root = document.querySelector<HTMLElement>('[data-controller="meetings--drag-and-drop"]')!;
    const controller = Stimulus.getControllerForElementAndIdentifier(
      root,
      'meetings--drag-and-drop',
    ) as GenericDragAndDropController;
    const agenda1 = document.getElementById('agenda-1')!;
    const agenda2 = document.getElementById('agenda-2')!;
    const agenda3 = document.getElementById('agenda-3')!;
    const section1 = document.getElementById('section-1')!;
    const section2 = document.getElementById('section-2')!;
    const agendaList1 = document.getElementById('agenda-list-1')!;
    const agendaList2 = document.getElementById('agenda-list-2')!;

    expect((controller as unknown as {
      findContainerFor:(item:HTMLElement) => HTMLElement|null;
    }).findContainerFor(agenda1)).toBe(agendaList1);

    expect((controller as unknown as {
      findContainerFor:(item:HTMLElement) => HTMLElement|null;
    }).findContainerFor(agenda3)).toBe(agendaList2);

    const sortables = (controller as unknown as {
      sortables:Map<HTMLElement, { index:number }>;
    }).sortables;

    expect(sortables.get(section1)?.index).toBe(0);
    expect(sortables.get(section2)?.index).toBe(1);
    expect(sortables.get(agenda1)?.index).toBe(0);
    expect(sortables.get(agenda2)?.index).toBe(1);
    expect(sortables.get(agenda3)?.index).toBe(0);
  });

  it('prefers the nested matching drop container for cross-container drops', async () => {
    Stimulus.stop();
    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('meetings--drag-and-drop', GenericDragAndDropController);

    appendTemplate(`
      <div data-controller="meetings--drag-and-drop">
        <div
          id="sections"
          data-meetings--drag-and-drop-target="container"
          data-target-allowed-drag-type="section"
        >
          <section
            id="section-1"
            data-meetings--drag-and-drop-target="item"
            data-draggable-id="section-1"
            data-draggable-type="section"
            data-drop-url="/meetings/1/sections/1/drop"
          >
            <div class="DragHandle" aria-pressed="false"></div>
            <ul
              id="agenda-list-1"
              data-meetings--drag-and-drop-target="container"
              data-target-allowed-drag-type="agenda-item"
              data-target-id="1"
            >
              <li
                id="agenda-1"
                data-meetings--drag-and-drop-target="item"
                data-draggable-id="1"
                data-draggable-type="agenda-item"
                data-drop-url="/meetings/1/agenda_items/1/drop"
              >
                <div class="DragHandle" aria-pressed="true"></div>
              </li>
            </ul>
          </section>
          <section
            id="section-2"
            data-meetings--drag-and-drop-target="item"
            data-draggable-id="section-2"
            data-draggable-type="section"
            data-drop-url="/meetings/1/sections/2/drop"
          >
            <div class="DragHandle" aria-pressed="false"></div>
            <ul
              id="agenda-list-2"
              data-meetings--drag-and-drop-target="container"
              data-target-allowed-drag-type="agenda-item"
              data-target-id="2"
            >
              <li
                id="agenda-2"
                data-meetings--drag-and-drop-target="item"
                data-draggable-id="2"
                data-draggable-type="agenda-item"
                data-drop-url="/meetings/1/agenda_items/2/drop"
              >
                <div class="DragHandle" aria-pressed="false"></div>
              </li>
            </ul>
          </section>
        </div>
      </div>
    `);
    await nextFrame();

    const root = document.querySelector<HTMLElement>('[data-controller="meetings--drag-and-drop"]')!;
    const controller = Stimulus.getControllerForElementAndIdentifier(
      root,
      'meetings--drag-and-drop',
    ) as GenericDragAndDropController;
    const agenda1 = document.getElementById('agenda-1')!;
    const agendaList1 = document.getElementById('agenda-list-1')!;
    const agendaList2 = document.getElementById('agenda-list-2')!;
    const section2 = document.getElementById('section-2')!;

    agenda1.setAttribute('data-generic-dnd-preview-active', '');
    (controller as unknown as { draggedElement:HTMLElement|null }).draggedElement = agenda1;
    (controller as unknown as { dragOriginSource:Element|null }).dragOriginSource = agendaList1;
    const dropSpy = spyOn(controller, 'drop').and.resolveTo();

    await (controller as unknown as {
      onDragEnd:(event:{ canceled:boolean; operation:{ target:{ element:HTMLElement } } }) => Promise<void>;
    }).onDragEnd({
      canceled: false,
      operation: {
        target: {
          element: section2,
        },
      },
    });

    expect(dropSpy).toHaveBeenCalledWith(agenda1, agendaList2, agendaList1, null);
  });

  it('derives a valid cross-container position from the dnd-kit drop target', async () => {
    Stimulus.stop();
    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('meetings--drag-and-drop', GenericDragAndDropController);

    appendTemplate(`
      <div data-controller="meetings--drag-and-drop">
        <div
          id="sections"
          data-meetings--drag-and-drop-target="container"
          data-target-allowed-drag-type="section"
        >
          <section
            id="section-1"
            data-meetings--drag-and-drop-target="item"
            data-draggable-id="section-1"
            data-draggable-type="section"
            data-drop-url="/meetings/1/sections/1/drop"
          >
            <div class="DragHandle" aria-pressed="false"></div>
            <ul
              id="agenda-list-1"
              data-meetings--drag-and-drop-target="container"
              data-target-allowed-drag-type="agenda-item"
              data-target-id="1"
            >
              <li
                id="agenda-1"
                data-meetings--drag-and-drop-target="item"
                data-draggable-id="1"
                data-draggable-type="agenda-item"
                data-drop-url="/meetings/1/agenda_items/1/drop"
              >
                <div class="DragHandle" aria-pressed="false"></div>
              </li>
            </ul>
          </section>
          <section
            id="section-2"
            data-meetings--drag-and-drop-target="item"
            data-draggable-id="section-2"
            data-draggable-type="section"
            data-drop-url="/meetings/1/sections/2/drop"
          >
            <div class="DragHandle" aria-pressed="false"></div>
            <ul
              id="agenda-list-2"
              data-meetings--drag-and-drop-target="container"
              data-target-allowed-drag-type="agenda-item"
              data-target-id="2"
            >
              <li
                id="agenda-2"
                data-meetings--drag-and-drop-target="item"
                data-draggable-id="2"
                data-draggable-type="agenda-item"
                data-drop-url="/meetings/1/agenda_items/2/drop"
              >
                <div class="DragHandle" aria-pressed="false"></div>
              </li>
            </ul>
          </section>
        </div>
      </div>
    `);
    await nextFrame();

    const root = document.querySelector<HTMLElement>('[data-controller="meetings--drag-and-drop"]')!;
    const controller = Stimulus.getControllerForElementAndIdentifier(
      root,
      'meetings--drag-and-drop',
    ) as GenericDragAndDropController;
    const agenda1 = document.getElementById('agenda-1')!;
    const agenda2 = document.getElementById('agenda-2')!;
    const agendaList2 = document.getElementById('agenda-list-2')!;

    (controller as unknown as {
      currentDropOperation:{
        target:{ element:HTMLElement; shape:{ center:{ y:number } } };
        shape:{ current:{ center:{ y:number } } };
      };
    }).currentDropOperation = {
      target: {
        element: agenda2,
        shape: {
          center: { y: 100 },
        },
      },
      shape: {
        current: {
          center: { y: 120 },
        },
      },
    };

    const data = (controller as unknown as {
      buildData:(el:Element, target:Element) => FormData;
    }).buildData(agenda1, agendaList2);

    expect(data.get('target_id')).toBe('2');
    expect(data.get('position')).toBe('2');
  });

  it('derives section reorder position from nested content inside the target section', async () => {
    Stimulus.stop();
    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('meetings--drag-and-drop', GenericDragAndDropController);

    appendTemplate(`
      <div data-controller="meetings--drag-and-drop">
        <div
          id="sections"
          data-meetings--drag-and-drop-target="container"
          data-target-allowed-drag-type="section"
        >
          <section
            id="section-1"
            data-meetings--drag-and-drop-target="item"
            data-draggable-id="section-1"
            data-draggable-type="section"
            data-drop-url="/meetings/1/sections/1/drop"
          >
            <div class="DragHandle" aria-pressed="false"></div>
          </section>
          <section
            id="section-2"
            data-meetings--drag-and-drop-target="item"
            data-draggable-id="section-2"
            data-draggable-type="section"
            data-drop-url="/meetings/1/sections/2/drop"
          >
            <div class="DragHandle" aria-pressed="false"></div>
            <ul>
              <li id="nested-target">Agenda preview</li>
            </ul>
          </section>
          <section
            id="section-3"
            data-meetings--drag-and-drop-target="item"
            data-draggable-id="section-3"
            data-draggable-type="section"
            data-drop-url="/meetings/1/sections/3/drop"
          >
            <div class="DragHandle" aria-pressed="false"></div>
          </section>
        </div>
      </div>
    `);
    await nextFrame();

    const root = document.querySelector<HTMLElement>('[data-controller="meetings--drag-and-drop"]')!;
    const controller = Stimulus.getControllerForElementAndIdentifier(
      root,
      'meetings--drag-and-drop',
    ) as GenericDragAndDropController;
    const sections = document.getElementById('sections')!;
    const section3 = document.getElementById('section-3')!;
    const nestedTarget = document.getElementById('nested-target')!;

    (controller as unknown as {
      currentDropOperation:{
        target:{ element:HTMLElement; shape:{ center:{ y:number } } };
        shape:{ current:{ center:{ y:number } } };
      };
    }).currentDropOperation = {
      target: {
        element: nestedTarget,
        shape: {
          center: { y: 100 },
        },
      },
      shape: {
        current: {
          center: { y: 80 },
        },
      },
    };

    const data = (controller as unknown as {
      buildData:(el:Element, target:Element) => FormData;
    }).buildData(section3, sections);

    expect(data.get('position')).toBe('2');
  });

  it('visibly reorders section DOM on dragend when the drop target is nested content', async () => {
    Stimulus.stop();
    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('meetings--drag-and-drop', GenericDragAndDropController);

    appendTemplate(`
      <div data-controller="meetings--drag-and-drop">
        <div
          id="sections"
          data-meetings--drag-and-drop-target="container"
          data-target-allowed-drag-type="section"
        >
          <section
            id="section-1"
            data-meetings--drag-and-drop-target="item"
            data-draggable-id="section-1"
            data-draggable-type="section"
            data-drop-url="/meetings/1/sections/1/drop"
          >
            <div class="DragHandle" aria-pressed="false"></div>
          </section>
          <section
            id="section-2"
            data-meetings--drag-and-drop-target="item"
            data-draggable-id="section-2"
            data-draggable-type="section"
            data-drop-url="/meetings/1/sections/2/drop"
          >
            <div class="DragHandle" aria-pressed="false"></div>
            <ul>
              <li id="nested-target-drop">Agenda preview</li>
            </ul>
          </section>
          <section
            id="section-3"
            data-meetings--drag-and-drop-target="item"
            data-draggable-id="section-3"
            data-draggable-type="section"
            data-drop-url="/meetings/1/sections/3/drop"
          >
            <div class="DragHandle" aria-pressed="true"></div>
          </section>
        </div>
      </div>
    `);
    await nextFrame();

    const root = document.querySelector<HTMLElement>('[data-controller="meetings--drag-and-drop"]')!;
    const controller = Stimulus.getControllerForElementAndIdentifier(
      root,
      'meetings--drag-and-drop',
    ) as GenericDragAndDropController;
    const sections = document.getElementById('sections')!;
    const section3 = document.getElementById('section-3')!;
    const nestedTarget = document.getElementById('nested-target-drop')!;

    section3.setAttribute('data-generic-dnd-preview-active', '');
    (controller as unknown as { draggedElement:HTMLElement|null }).draggedElement = section3;
    (controller as unknown as { dragOriginSource:Element|null }).dragOriginSource = sections;
    const dropSpy = spyOn(controller, 'drop').and.resolveTo();

    await (controller as unknown as {
      onDragEnd:(event:{
        canceled:boolean;
        operation:{
          target:{ element:HTMLElement; shape:{ center:{ y:number } } };
          shape:{ current:{ center:{ y:number } } };
        };
      }) => Promise<void>;
    }).onDragEnd({
      canceled: false,
      operation: {
        target: {
          element: nestedTarget,
          shape: {
            center: { y: 100 },
          },
        },
        shape: {
          current: {
            center: { y: 80 },
          },
        },
      },
    });

    expect(Array.from(sections.children).map((el) => el.id)).toEqual(['section-1', 'section-3', 'section-2']);
    expect(dropSpy).toHaveBeenCalledWith(section3, sections, sections, null);
  });
});

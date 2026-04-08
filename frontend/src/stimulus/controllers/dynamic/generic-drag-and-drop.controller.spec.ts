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
/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-empty-function */

import { Application } from '@hotwired/stimulus';
import { FetchRequest, FetchResponse } from '@rails/request.js';
import GenericDragAndDropController from './generic-drag-and-drop.controller';

const nextFrame = () => new Promise((resolve) => requestAnimationFrame(resolve));

describe('GenericDragAndDropController', () => {
  let Stimulus:Application;
  let fixturesElement:HTMLElement;

  const DomAutoscrollService = class {
    destroy() {}
  };

  interface TestableController {
    monitorCleanup:(() => void)|null;
    dropTargetCleanups:Map<HTMLElement, () => void>;
    draggableCleanups:Map<HTMLElement, () => void>;
    dragOriginSource:Element|null;
    dragOriginNextSibling:Element|null;
    disconnect():void;
    drop(el:Element, target:Element, source:Element|null, sibling:Element|null):Promise<void>;
    buildData(el:Element, target:Element):FormData;
  }

  function appendTemplate(html:string) {
    const template = document.createElement('template');
    template.innerHTML = html.trim();
    fixturesElement.appendChild(template.content.cloneNode(true));
  }

  function findController():TestableController {
    const controller:unknown = Stimulus.getControllerForElementAndIdentifier(
      fixturesElement.querySelector('[data-controller~="generic-drag-and-drop"]')!,
      'generic-drag-and-drop',
    );

    return controller as TestableController;
  }

  function buildFixture(options:{ positionMode?:'index'|'prev_id' } = {}) {
    const positionMode = options.positionMode ? `data-generic-drag-and-drop-position-mode-value="${options.positionMode}"` : '';

    return `
      <div data-controller="generic-drag-and-drop" ${positionMode}>
        <ul
          id="stories"
          data-generic-drag-and-drop-target="container"
          data-target-id="sprint:1"
          data-target-allowed-drag-type="story">
          <li
            id="story-1"
            data-generic-drag-and-drop-target="draggable"
            data-draggable-id="1"
            data-draggable-type="story"
            data-drop-url="/stories/1">
            <button type="button" class="DragHandle">Drag 1</button>
          </li>
          <li
            id="story-2"
            data-generic-drag-and-drop-target="draggable"
            data-draggable-id="2"
            data-draggable-type="story"
            data-drop-url="/stories/2">
            <button type="button" class="DragHandle">Drag 2</button>
          </li>
        </ul>
      </div>
    `;
  }

  beforeEach(() => {
    fixturesElement = document.createElement('div');
    document.body.appendChild(fixturesElement);

    (window as any).OpenProject = {
      getPluginContext: () => Promise.resolve({
        classes: {
          DomAutoscrollService,
        },
      }),
    };
  });

  afterEach(() => {
    Stimulus?.stop();
    fixturesElement.remove();
  });

  async function startWithFixture(html:string) {
    appendTemplate(html);

    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('generic-drag-and-drop', GenericDragAndDropController);

    await nextFrame();
    await nextFrame();
  }

  it('tracks cleanup handles for the monitor and explicit target registrations', async () => {
    await startWithFixture(buildFixture());

    const controller = findController();

    expect(controller.monitorCleanup).toEqual(jasmine.any(Function));
    expect(controller.dropTargetCleanups.size).toBe(3);
    expect(controller.draggableCleanups.size).toBe(2);
  });

  it('builds index-based form data with the target id', async () => {
    await startWithFixture(buildFixture());

    const controller = findController();
    const container = fixturesElement.querySelector('#stories')!;
    const story2 = fixturesElement.querySelector('#story-2')!;

    container.insertBefore(story2, container.firstElementChild);

    const data = controller.buildData(story2, container);

    expect(data.get('position')).toBe('1');
    expect(data.get('target_id')).toBe('sprint:1');
  });

  it('builds prev_id form data from the preceding draggable', async () => {
    await startWithFixture(buildFixture({ positionMode: 'prev_id' }));

    const controller = findController();
    const container = fixturesElement.querySelector('#stories')!;
    const story2 = fixturesElement.querySelector('#story-2')!;

    const dataAtBottom = controller.buildData(story2, container);

    expect(dataAtBottom.get('prev_id')).toBe('1');

    container.insertBefore(story2, container.firstElementChild);

    const dataAtTop = controller.buildData(story2, container);

    expect(dataAtTop.get('prev_id')).toBe('');
  });

  it('disconnect clears registered cleanup handles', async () => {
    await startWithFixture(buildFixture());

    const controller = findController();

    controller.disconnect();

    expect(controller.monitorCleanup).toBeNull();
    expect(controller.dropTargetCleanups.size).toBe(0);
    expect(controller.draggableCleanups.size).toBe(0);
  });

  it('reverts an optimistic move when the drop request fails', async () => {
    await startWithFixture(buildFixture());

    const controller = findController();
    const container = fixturesElement.querySelector<HTMLElement>('#stories')!;
    const story1 = fixturesElement.querySelector<HTMLElement>('#story-1')!;
    const story2 = fixturesElement.querySelector<HTMLElement>('#story-2')!;

    container.appendChild(story1);
    controller.dragOriginSource = container;
    controller.dragOriginNextSibling = story2;

    spyOn(FetchRequest.prototype, 'perform').and.resolveTo({
      ok: false,
      statusCode: 500,
    } as unknown as FetchResponse);

    await controller.drop(story1, container, null, null);

    expect(Array.from(container.children).map((child) => (child as HTMLElement).id)).toEqual(['story-1', 'story-2']);
  });
});

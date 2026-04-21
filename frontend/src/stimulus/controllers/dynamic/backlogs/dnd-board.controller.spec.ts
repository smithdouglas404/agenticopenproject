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
import { attachClosestEdge } from '@atlaskit/pragmatic-drag-and-drop-hitbox/closest-edge';
import { FetchRequest, FetchResponse } from '@rails/request.js';
import BacklogsDndBoardController from './dnd-board.controller';
import BacklogsDndListController from './dnd-list.controller';
import BacklogsDndItemController from './dnd-item.controller';
import { pragmaticDnd } from './pragmatic-dnd';

const nextFrame = () => new Promise((resolve) => requestAnimationFrame(resolve));

interface DropDestination {
  element:Element;
  data:Record<string, unknown>;
}

interface TestableBoardController {
  disconnect():void;
  handleMonitorDrop(args:{
    source:{
      element:HTMLElement;
      data?:{
        itemType?:string;
      };
    };
    location:{ current:{ dropTargets:DropDestination[] } };
  }):Promise<void>;
}

describe('BacklogsDndBoardController', () => {
  let Stimulus:Application;
  let fixturesElement:HTMLElement;
  let capturedRequestBody:FormData|null;

  function appendTemplate(html:string) {
    const template = document.createElement('template');
    template.innerHTML = html.trim();
    fixturesElement.appendChild(template.content.cloneNode(true));
  }

  function buildFixture() {
    return `
      <section
        data-controller="backlogs--dnd-board"
        data-backlogs--dnd-board-backlogs--dnd-list-outlet=".js-dnd-list"
        data-backlogs--dnd-board-backlogs--dnd-item-outlet=".js-dnd-item">
        <ul
          id="sprint-1"
          class="js-dnd-list"
          data-controller="backlogs--dnd-list"
          data-backlogs--dnd-list-list-id-value="sprint:1">
          <li
            id="story-1"
            class="js-dnd-item"
            data-controller="backlogs--dnd-item"
            data-backlogs--dnd-item-item-id-value="1"
            data-backlogs--dnd-item-item-type-value="story"
            data-backlogs--dnd-item-drop-url-value="/stories/1">
            <button type="button" class="DragHandle">Drag 1</button>
          </li>
          <li
            id="story-2"
            class="js-dnd-item"
            data-controller="backlogs--dnd-item"
            data-backlogs--dnd-item-item-id-value="2"
            data-backlogs--dnd-item-item-type-value="story"
            data-backlogs--dnd-item-drop-url-value="/stories/2">
            <button type="button" class="DragHandle">Drag 2</button>
          </li>
        </ul>

        <ul
          id="backlog-1"
          class="js-dnd-list"
          data-controller="backlogs--dnd-list"
          data-backlogs--dnd-list-list-id-value="version:1">
          <li
            id="story-3"
            class="js-dnd-item"
            data-controller="backlogs--dnd-item"
            data-backlogs--dnd-item-item-id-value="3"
            data-backlogs--dnd-item-item-type-value="story"
            data-backlogs--dnd-item-drop-url-value="/stories/3">
            <button type="button" class="DragHandle">Drag 3</button>
          </li>
        </ul>
      </section>
    `;
  }

  function itemDropData(element:HTMLElement, edge:'top'|'bottom') {
    return attachClosestEdge(
      {
        kind: 'item',
        itemId: element.getAttribute('data-backlogs--dnd-item-item-id-value'),
      },
      {
        element,
        input: {
          altKey: false,
          button: 0,
          buttons: 1,
          clientX: 0,
          clientY: edge === 'top' ? 0 : Number.MAX_SAFE_INTEGER,
          ctrlKey: false,
          metaKey: false,
          pageX: 0,
          pageY: edge === 'top' ? 0 : Number.MAX_SAFE_INTEGER,
          shiftKey: false,
        },
        allowedEdges: ['top', 'bottom'],
      },
    );
  }

  function findBoardController():TestableBoardController {
    return Stimulus.getControllerForElementAndIdentifier(
      fixturesElement.querySelector('[data-controller~="backlogs--dnd-board"]')!,
      'backlogs--dnd-board',
    ) as unknown as TestableBoardController;
  }

  async function startWithFixture() {
    appendTemplate(buildFixture());

    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('backlogs--dnd-board', BacklogsDndBoardController);
    Stimulus.register('backlogs--dnd-list', BacklogsDndListController);
    Stimulus.register('backlogs--dnd-item', BacklogsDndItemController);

    await nextFrame();
    await nextFrame();
  }

  beforeEach(() => {
    fixturesElement = document.createElement('div');
    document.body.appendChild(fixturesElement);
    capturedRequestBody = null;
  });

  afterEach(() => {
    Stimulus?.stop();
    fixturesElement.remove();
  });

  it('reorders an item within a list and persists target_id with prev_id', async () => {
    await startWithFixture();

    const board = findBoardController();
    const sprint = fixturesElement.querySelector<HTMLElement>('#sprint-1')!;
    const story1 = fixturesElement.querySelector<HTMLElement>('#story-1')!;
    const story2 = fixturesElement.querySelector<HTMLElement>('#story-2')!;

    spyOn(FetchRequest.prototype, 'perform').and.resolveTo({
      ok: true,
      statusCode: 200,
    } as unknown as FetchResponse);
    (FetchRequest.prototype.perform as jasmine.Spy).and.callFake(function(this:{ options:{ body:FormData } }) {
      capturedRequestBody = this.options.body;

      return Promise.resolve({
        ok: true,
        statusCode: 200,
      } as FetchResponse);
    });

    await board.handleMonitorDrop({
      source: { element: story2, data: { itemType: 'story' } },
      location: {
        current: {
          dropTargets: [
            {
              element: story1,
              data: itemDropData(story1, 'top'),
            },
          ],
        },
      },
    });

    expect(Array.from(sprint.children).map((element) => (element as HTMLElement).id)).toEqual([
      'story-2',
      'story-1',
    ]);

    expect(capturedRequestBody?.get('target_id')).toBe('sprint:1');
    expect(capturedRequestBody?.get('prev_id')).toBe('');
  });

  it('moves an item across lists and persists the destination list and previous sibling', async () => {
    await startWithFixture();

    const board = findBoardController();
    const backlog = fixturesElement.querySelector<HTMLElement>('#backlog-1')!;
    const story2 = fixturesElement.querySelector<HTMLElement>('#story-2')!;
    const story3 = fixturesElement.querySelector<HTMLElement>('#story-3')!;

    spyOn(FetchRequest.prototype, 'perform').and.resolveTo({
      ok: true,
      statusCode: 200,
    } as unknown as FetchResponse);
    (FetchRequest.prototype.perform as jasmine.Spy).and.callFake(function(this:{ options:{ body:FormData } }) {
      capturedRequestBody = this.options.body;

      return Promise.resolve({
        ok: true,
        statusCode: 200,
      } as FetchResponse);
    });

    await board.handleMonitorDrop({
      source: { element: story2, data: { itemType: 'story' } },
      location: {
        current: {
          dropTargets: [
            {
              element: story3,
              data: itemDropData(story3, 'bottom'),
            },
          ],
        },
      },
    });

    expect(Array.from(backlog.children).map((element) => (element as HTMLElement).id)).toEqual([
      'story-3',
      'story-2',
    ]);

    expect(capturedRequestBody?.get('target_id')).toBe('version:1');
    expect(capturedRequestBody?.get('prev_id')).toBe('3');
  });

  it('drops onto a list target and appends to the list', async () => {
    await startWithFixture();

    const board = findBoardController();
    const backlog = fixturesElement.querySelector<HTMLElement>('#backlog-1')!;
    const story1 = fixturesElement.querySelector<HTMLElement>('#story-1')!;

    spyOn(FetchRequest.prototype, 'perform').and.resolveTo({
      ok: true,
      statusCode: 200,
    } as unknown as FetchResponse);
    (FetchRequest.prototype.perform as jasmine.Spy).and.callFake(function(this:{ options:{ body:FormData } }) {
      capturedRequestBody = this.options.body;

      return Promise.resolve({
        ok: true,
        statusCode: 200,
      } as FetchResponse);
    });

    await board.handleMonitorDrop({
      source: { element: story1, data: { itemType: 'story' } },
      location: {
        current: {
          dropTargets: [
            {
              element: backlog,
              data: {
                kind: 'list',
                listId: 'version:1',
              },
            },
          ],
        },
      },
    });

    expect(Array.from(backlog.children).map((element) => (element as HTMLElement).id)).toEqual([
      'story-3',
      'story-1',
    ]);

    expect(capturedRequestBody?.get('target_id')).toBe('version:1');
    expect(capturedRequestBody?.get('prev_id')).toBe('3');
  });

  it('reverts the optimistic move when the request fails', async () => {
    await startWithFixture();

    const board = findBoardController();
    const sprint = fixturesElement.querySelector<HTMLElement>('#sprint-1')!;
    const story2 = fixturesElement.querySelector<HTMLElement>('#story-2')!;
    const story3 = fixturesElement.querySelector<HTMLElement>('#story-3')!;

    spyOn(FetchRequest.prototype, 'perform').and.resolveTo({
      ok: false,
      statusCode: 500,
    } as unknown as FetchResponse);

    await board.handleMonitorDrop({
      source: { element: story2, data: { itemType: 'story' } },
      location: {
        current: {
          dropTargets: [
            {
              element: story3,
              data: itemDropData(story3, 'top'),
            },
          ],
        },
      },
    });

    expect(Array.from(sprint.children).map((element) => (element as HTMLElement).id)).toEqual([
      'story-1',
      'story-2',
    ]);
  });

  it('uses the placeholder prev-id sentinel when the previous sibling is not a draggable item', async () => {
    await startWithFixture();

    const board = findBoardController();
    const backlog = fixturesElement.querySelector<HTMLElement>('#backlog-1')!;
    const story1 = fixturesElement.querySelector<HTMLElement>('#story-1')!;
    const story3 = fixturesElement.querySelector<HTMLElement>('#story-3')!;
    const placeholder = document.createElement('li');
    placeholder.id = 'show-more';
    placeholder.setAttribute('data-backlogs--dnd-prev-id-value', '99');
    backlog.insertBefore(placeholder, story3.nextSibling);

    spyOn(FetchRequest.prototype, 'perform').and.resolveTo({
      ok: true,
      statusCode: 200,
    } as unknown as FetchResponse);
    (FetchRequest.prototype.perform as jasmine.Spy).and.callFake(function(this:{ options:{ body:FormData } }) {
      capturedRequestBody = this.options.body;

      return Promise.resolve({
        ok: true,
        statusCode: 200,
      } as FetchResponse);
    });

    await board.handleMonitorDrop({
      source: { element: story1, data: { itemType: 'story' } },
      location: {
        current: {
          dropTargets: [
            {
              element: backlog,
              data: {
                kind: 'list',
                listId: 'version:1',
              },
            },
          ],
        },
      },
    });

    expect(capturedRequestBody?.get('prev_id')).toBe('99');
  });

  it('short-circuits drop-on-self without sending a request', async () => {
    await startWithFixture();

    const board = findBoardController();
    const sprint = fixturesElement.querySelector<HTMLElement>('#sprint-1')!;
    const story1 = fixturesElement.querySelector<HTMLElement>('#story-1')!;
    const performSpy = spyOn(FetchRequest.prototype, 'perform');

    await board.handleMonitorDrop({
      source: { element: story1, data: { itemType: 'story' } },
      location: {
        current: {
          dropTargets: [
            {
              element: story1,
              data: itemDropData(story1, 'top'),
            },
          ],
        },
      },
    });

    expect(performSpy).not.toHaveBeenCalled();
    expect(Array.from(sprint.children).map((element) => (element as HTMLElement).id)).toEqual([
      'story-1',
      'story-2',
    ]);
  });

  it('marks the board busy and ignores additional drops while a request is in flight', async () => {
    await startWithFixture();

    const boardElement = fixturesElement.querySelector<HTMLElement>('[data-controller~="backlogs--dnd-board"]')!;
    const board = findBoardController();
    const backlog = fixturesElement.querySelector<HTMLElement>('#backlog-1')!;
    const sprint = fixturesElement.querySelector<HTMLElement>('#sprint-1')!;
    const story1 = fixturesElement.querySelector<HTMLElement>('#story-1')!;
    const story2 = fixturesElement.querySelector<HTMLElement>('#story-2')!;
    const story3 = fixturesElement.querySelector<HTMLElement>('#story-3')!;

    let resolveRequest:(value:FetchResponse) => void = () => undefined;
    const performSpy = spyOn(FetchRequest.prototype, 'perform').and.callFake(() => {
      return new Promise<FetchResponse>((resolve) => {
        resolveRequest = resolve;
      });
    });

    const firstDrop = board.handleMonitorDrop({
      source: { element: story2, data: { itemType: 'story' } },
      location: {
        current: {
          dropTargets: [
            {
              element: story3,
              data: itemDropData(story3, 'bottom'),
            },
          ],
        },
      },
    });

    expect(boardElement.classList.contains('is-dnd-busy')).toBe(true);
    expect(boardElement.getAttribute('aria-busy')).toBe('true');

    await board.handleMonitorDrop({
      source: { element: story1, data: { itemType: 'story' } },
      location: {
        current: {
          dropTargets: [
            {
              element: backlog,
              data: {
                kind: 'list',
                listId: 'version:1',
              },
            },
          ],
        },
      },
    });

    expect(performSpy).toHaveBeenCalledTimes(1);
    expect(Array.from(sprint.children).map((element) => (element as HTMLElement).id)).toEqual([
      'story-1',
    ]);

    resolveRequest({
      ok: true,
      statusCode: 200,
    } as FetchResponse);
    await firstDrop;

    expect(boardElement.classList.contains('is-dnd-busy')).toBe(false);
    expect(boardElement.getAttribute('aria-busy')).toBe('false');
  });

  it('registers a pragmatic monitor on connect and cleans it up on disconnect', async () => {
    const cleanup = jasmine.createSpy('cleanup');
    spyOn(pragmaticDnd, 'monitorForElements').and.returnValue(cleanup);

    await startWithFixture();

    expect(pragmaticDnd.monitorForElements).toHaveBeenCalled();

    findBoardController().disconnect();

    expect(cleanup).toHaveBeenCalled();
  });

  it('filters the global monitor to backlog story drags', async () => {
    let monitorArgs:{ canMonitor:(args:{ source:{ data:{ itemType?:string } } }) => boolean }|null = null;
    const cleanup = jasmine.createSpy('cleanup');
    spyOn(pragmaticDnd, 'monitorForElements').and.callFake((args) => {
      monitorArgs = args as typeof monitorArgs;

      return cleanup;
    });

    await startWithFixture();

    expect(monitorArgs).not.toBeNull();
    expect(monitorArgs!.canMonitor({ source: { data: { itemType: 'story' } } })).toBe(true);
    expect(monitorArgs!.canMonitor({ source: { data: { itemType: 'task' } } })).toBe(false);
    expect(monitorArgs!.canMonitor({ source: { data: {} } })).toBe(false);
  });

  it('resolves item and list controllers from outlet-backed maps', async () => {
    await startWithFixture();

    const board = findBoardController() as TestableBoardController & {
      itemControllerFor(element:HTMLElement):BacklogsDndItemController|null;
      listControllerFor(element:HTMLElement):BacklogsDndListController|null;
    };
    const story1 = fixturesElement.querySelector<HTMLElement>('#story-1')!;
    const sprint = fixturesElement.querySelector<HTMLElement>('#sprint-1')!;
    spyOn(Application.prototype, 'getControllerForElementAndIdentifier').and.returnValue(null);

    expect(board.itemControllerFor(story1)).not.toBeNull();
    expect(board.itemControllerFor(story1)?.itemIdValue).toBe('1');
    expect(board.listControllerFor(sprint)).not.toBeNull();
    expect(board.listControllerFor(sprint)?.listIdValue).toBe('sprint:1');
  });
});

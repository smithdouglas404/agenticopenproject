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
import { AutoScroller, DragDropManager, Feedback } from '@dnd-kit/dom';
import DndSurfaceController from './dnd-surface.controller';
import DndListController from './dnd-list.controller';
import ItemController from './item.controller';

const nextFrame = () => new Promise((resolve) => requestAnimationFrame(resolve));

interface ConstraintWithValue {
  constructor:{ name:string };
  options:{ value:number };
}

interface SurfaceTestEvent {
  canceled:boolean;
  operation:{
    source:{ element:HTMLElement; id:string|undefined };
    target:{ element:HTMLElement }|null;
  };
}

interface SurfaceTestController {
  manager:DragDropManager|null;
  activationConstraintsFor(event:{ pointerType?:string; target?:EventTarget|null }):ConstraintWithValue[];
  onBeforeDragStart(event:SurfaceTestEvent):void;
  onDragEnd(event:SurfaceTestEvent):Promise<void>;
  persistMove(dropUrl:string, data:FormData):Promise<boolean>;
}

describe('Backlogs::DndSurfaceController', () => {
  let Stimulus:Application;
  let fixturesElement:HTMLElement;

  const surfaceTemplate = `
    <div
      id="backlogs-surface"
      data-controller="backlogs--dnd-surface"
      data-backlogs--dnd-surface-position-mode-value="prev_id"
    >
      <section
        id="inbox-shell"
        data-controller="backlogs--dnd-list"
        data-backlogs--dnd-list-target-id-value="inbox"
      >
        <ul id="inbox-list">
          <li
            id="work_package_1"
            data-controller="backlogs--item"
            data-draggable-id="1"
            data-draggable-type="story"
            data-drop-url="/move/1"
            data-backlogs--item-selected-class="Box-row--blue"
          ></li>
          <li
            id="work_package_2"
            data-controller="backlogs--item"
            data-draggable-id="2"
            data-draggable-type="story"
            data-drop-url="/move/2"
            data-backlogs--item-selected-class="Box-row--blue"
          ></li>
        </ul>
      </section>

      <section
        id="sprint-shell"
        data-controller="backlogs--dnd-list"
        data-backlogs--dnd-list-target-id-value="sprint:5"
      >
        <ul id="sprint-list">
          <li
            id="work_package_7"
            data-controller="backlogs--item"
            data-draggable-id="7"
            data-draggable-type="story"
            data-drop-url="/move/7"
            data-backlogs--item-selected-class="Box-row--blue"
          ></li>
        </ul>
      </section>
    </div>
  `;

  function appendTemplate(html:string) {
    const template = document.createElement('template');
    template.innerHTML = html.trim();
    fixturesElement.appendChild(template.content.cloneNode(true));
  }

  function surfaceController():DndSurfaceController {
    return Stimulus.getControllerForElementAndIdentifier(
      document.getElementById('backlogs-surface')!,
      'backlogs--dnd-surface',
    ) as DndSurfaceController;
  }

  function formDataToObject(data:FormData):Record<string, string> {
    return Object.fromEntries(Array.from(data.entries()).map(([key, value]) => [key, value instanceof File ? value.name : value]));
  }

  function dragEventFor(source:HTMLElement, target:HTMLElement|null, canceled = false):SurfaceTestEvent {
    return {
      canceled,
      operation: {
        source: { element: source, id: source.dataset.draggableId },
        target: target ? { element: target } : null,
      },
    };
  }

  beforeEach(() => {
    fixturesElement = document.createElement('div');
    document.body.appendChild(fixturesElement);
    delete window.opBacklogsDndSurfaceDebug;
  });

  beforeEach(async () => {
    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('backlogs--item', ItemController);
    Stimulus.register('backlogs--dnd-list', DndListController);
    Stimulus.register('backlogs--dnd-surface', DndSurfaceController);
    await nextFrame();
  });

  afterEach(() => {
    fixturesElement.remove();
    Stimulus.stop();
  });

  it('creates a drag-drop manager with overlay and auto-scroll plugins', async () => {
    appendTemplate(surfaceTemplate);
    await nextFrame();

    const controller = surfaceController();
    const manager = controller.manager;

    expect(manager).toEqual(jasmine.any(DragDropManager));
    expect(manager?.plugins.some((plugin:unknown) => plugin instanceof Feedback)).toBeTrue();
    expect(manager?.plugins.some((plugin:unknown) => plugin instanceof AutoScroller)).toBeTrue();
  });

  it('records debug telemetry when registrations sync on connect and mutation', async () => {
    appendTemplate(surfaceTemplate);
    await nextFrame();

    expect(window.opBacklogsDndSurfaceDebug?.syncRegistrations.calls).toBe(1);
    expect(window.opBacklogsDndSurfaceDebug?.syncRegistrations.lastReason).toBe('connect');

    document.getElementById('inbox-list')!.insertAdjacentHTML('beforeend', `
      <li
        id="work_package_9"
        data-controller="backlogs--item"
        data-draggable-id="9"
        data-draggable-type="story"
        data-drop-url="/move/9"
        data-backlogs--item-selected-class="Box-row--blue"
      ></li>
    `);

    await nextFrame();
    await nextFrame();

    expect(window.opBacklogsDndSurfaceDebug?.syncRegistrations.calls).toBe(2);
    expect(window.opBacklogsDndSurfaceDebug?.syncRegistrations.lastReason).toBe('mutation');
    expect(window.opBacklogsDndSurfaceDebug?.syncRegistrations.lastItemCount).toBe(4);
  });

  it('strips default placeholder attributes from the cloned placeholder only', async () => {
    appendTemplate(surfaceTemplate);
    await nextFrame();

    const controller = surfaceController() as unknown as SurfaceTestController;
    const source = document.getElementById('work_package_1')!;
    const placeholder = source.cloneNode(true) as HTMLElement;
    placeholder.setAttribute('data-dnd-placeholder', 'hidden');

    controller.onBeforeDragStart(dragEventFor(source, source));
    source.insertAdjacentElement('afterend', placeholder);

    await nextFrame();

    expect(source.id).toBe('work_package_1');
    expect(source.getAttribute('data-controller')).toBe('backlogs--item');
    expect(placeholder.id).toBe('');
    expect(placeholder.hasAttribute('data-controller')).toBeFalse();
  });

  it('uses a custom placeholder strip value when provided on the draggable host', async () => {
    appendTemplate(surfaceTemplate);
    await nextFrame();

    const controller = surfaceController() as unknown as SurfaceTestController;
    const source = document.getElementById('work_package_1')!;
    source.setAttribute('data-backlogs--item-placeholder-strip-attributes-value', 'id data-controller data-drop-url');

    const placeholder = source.cloneNode(true) as HTMLElement;
    placeholder.setAttribute('data-dnd-placeholder', 'hidden');

    controller.onBeforeDragStart(dragEventFor(source, source));
    source.insertAdjacentElement('afterend', placeholder);

    await nextFrame();

    expect(source.getAttribute('data-drop-url')).toBe('/move/1');
    expect(placeholder.hasAttribute('data-drop-url')).toBeFalse();
  });

  it('uses a distance threshold for mouse input and a press delay for touch input', async () => {
    appendTemplate(surfaceTemplate);
    await nextFrame();

    const controller = surfaceController() as unknown as SurfaceTestController;

    const mouseConstraints = controller.activationConstraintsFor({
      pointerType: 'mouse',
      target: document.getElementById('work_package_1'),
    });
    const touchConstraints = controller.activationConstraintsFor({
      pointerType: 'touch',
      target: document.getElementById('work_package_1'),
    });

    expect(mouseConstraints.map((constraint) => constraint.constructor.name)).toEqual(['DelayConstraint', 'DistanceConstraint']);
    expect(mouseConstraints[0].options.value).toBe(200);
    expect(mouseConstraints[1].options.value).toBe(5);
    expect(touchConstraints.map((constraint) => constraint.constructor.name)).toEqual(['DelayConstraint']);
    expect(touchConstraints[0].options.value).toBe(250);
  });

  it('persists a same-list reorder using the moved item drop url and prev_id', async () => {
    appendTemplate(surfaceTemplate);
    await nextFrame();

    const controller = surfaceController() as unknown as SurfaceTestController;
    const moved = document.getElementById('work_package_2')!;
    const target = document.getElementById('work_package_1')!;

    target.parentElement!.insertBefore(moved, target);

    const persistMove = spyOn(controller, 'persistMove').and.resolveTo(true);

    controller.onBeforeDragStart(dragEventFor(moved, target));
    await controller.onDragEnd(dragEventFor(moved, target));

    expect(persistMove).toHaveBeenCalledOnceWith('/move/2', jasmine.any(FormData));
    expect(formDataToObject(persistMove.calls.mostRecent().args[1])).toEqual({
      prev_id: '',
      target_id: 'inbox',
    });
  });

  it('persists a cross-list move with the destination target_id and previous sibling id', async () => {
    appendTemplate(surfaceTemplate);
    await nextFrame();

    const controller = surfaceController() as unknown as SurfaceTestController;
    const moved = document.getElementById('work_package_1')!;
    const targetList = document.getElementById('sprint-list')!;

    targetList.appendChild(moved);

    const persistMove = spyOn(controller, 'persistMove').and.resolveTo(true);

    controller.onBeforeDragStart(dragEventFor(moved, targetList));
    await controller.onDragEnd(dragEventFor(moved, targetList));

    expect(formDataToObject(persistMove.calls.mostRecent().args[1])).toEqual({
      prev_id: '7',
      target_id: 'sprint:5',
    });
  });

  it('reverts the optimistic move when persistence fails', async () => {
    appendTemplate(surfaceTemplate);
    await nextFrame();

    const controller = surfaceController() as unknown as SurfaceTestController;
    const moved = document.getElementById('work_package_1')!;
    const inboxList = document.getElementById('inbox-list')!;
    const sprintList = document.getElementById('sprint-list')!;

    controller.onBeforeDragStart(dragEventFor(moved, sprintList));
    sprintList.appendChild(moved);
    spyOn(controller, 'persistMove').and.resolveTo(false);

    await controller.onDragEnd(dragEventFor(moved, sprintList));

    expect(inboxList.firstElementChild?.id).toBe('work_package_1');
    expect(sprintList.lastElementChild?.id).toBe('work_package_7');
  });
});

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
import { extractClosestEdge } from '@atlaskit/pragmatic-drag-and-drop-hitbox/closest-edge';
import BacklogsDndItemController from './dnd-item.controller';
import { pragmaticDnd } from './pragmatic-dnd';

const nextFrame = () => new Promise((resolve) => requestAnimationFrame(resolve));

describe('BacklogsDndItemController', () => {
  let Stimulus:Application;
  let fixturesElement:HTMLElement;

  beforeEach(() => {
    fixturesElement = document.createElement('div');
    document.body.appendChild(fixturesElement);
  });

  afterEach(() => {
    Stimulus?.stop();
    fixturesElement.remove();
  });

  it('registers draggable and item drop targets on connect and cleans them up on disconnect', async () => {
    fixturesElement.innerHTML = `
      <ul>
        <li
          id="story-1"
          data-controller="backlogs--dnd-item"
          data-backlogs--dnd-item-item-id-value="1"
          data-backlogs--dnd-item-item-type-value="story"
          data-backlogs--dnd-item-drop-url-value="/stories/1"></li>
      </ul>
    `;

    const draggableCleanup = jasmine.createSpy('draggableCleanup');
    const dropTargetCleanup = jasmine.createSpy('dropTargetCleanup');

    spyOn(pragmaticDnd, 'draggable').and.returnValue(draggableCleanup);
    spyOn(pragmaticDnd, 'dropTargetForElements').and.returnValue(dropTargetCleanup);
    spyOn(pragmaticDnd, 'combine').and.callFake((...cleanups) => () => {
      cleanups.forEach((cleanup) => cleanup());
    });

    Stimulus = Application.start();
    Stimulus.register('backlogs--dnd-item', BacklogsDndItemController);

    await nextFrame();

    const storyElement = fixturesElement.querySelector<HTMLElement>('#story-1')!;

    expect(pragmaticDnd.draggable).toHaveBeenCalled();
    expect(pragmaticDnd.dropTargetForElements).toHaveBeenCalled();
    expect(pragmaticDnd.draggable).toHaveBeenCalledWith(jasmine.objectContaining({
      element: storyElement,
    }));

    const controller = Stimulus.getControllerForElementAndIdentifier(
      storyElement,
      'backlogs--dnd-item',
    ) as BacklogsDndItemController;
    controller.disconnect();

    expect(draggableCleanup).toHaveBeenCalled();
    expect(dropTargetCleanup).toHaveBeenCalled();
  });

  it('attaches closest-edge metadata from the pointer position', async () => {
    fixturesElement.innerHTML = `
      <ul>
        <li
          id="story-1"
          data-controller="backlogs--dnd-item"
          data-backlogs--dnd-item-item-id-value="1"
          data-backlogs--dnd-item-item-type-value="story"
          data-backlogs--dnd-item-drop-url-value="/stories/1"></li>
      </ul>
    `;

    let dropTargetArgs:{ getData:(args:{ input:{ clientX:number; clientY:number }; element:Element }) => Record<string, unknown> }|null = null;
    const noopCleanup = jasmine.createSpy('noopCleanup');

    spyOn(pragmaticDnd, 'draggable').and.returnValue(noopCleanup);
    spyOn(pragmaticDnd, 'dropTargetForElements').and.callFake((args) => {
      dropTargetArgs = args as typeof dropTargetArgs;

      return noopCleanup;
    });
    spyOn(pragmaticDnd, 'combine').and.callFake((...cleanups) => () => {
      cleanups.forEach((cleanup) => cleanup());
    });

    Stimulus = Application.start();
    Stimulus.register('backlogs--dnd-item', BacklogsDndItemController);

    await nextFrame();

    const element = fixturesElement.querySelector<HTMLElement>('#story-1')!;
    spyOn(element, 'getBoundingClientRect').and.returnValue({
      bottom: 180,
      left: 0,
      right: 200,
      top: 100,
      height: 80,
    } as DOMRect);

    expect(dropTargetArgs).not.toBeNull();
    expect(extractClosestEdge(dropTargetArgs!.getData({ input: { clientX: 100, clientY: 110 }, element }))).toBe('top');
    expect(extractClosestEdge(dropTargetArgs!.getData({ input: { clientX: 100, clientY: 170 }, element }))).toBe('bottom');
  });

  it('re-registers the draggable after turbo morph strips native drag state on the same element', async () => {
    fixturesElement.innerHTML = `
      <ul>
        <li
          id="story-1"
          data-controller="backlogs--dnd-item"
          data-backlogs--dnd-item-item-id-value="1"
          data-backlogs--dnd-item-item-type-value="story"
          data-backlogs--dnd-item-drop-url-value="/stories/1"></li>
      </ul>
    `;

    const noopCleanup = jasmine.createSpy('noopCleanup');
    spyOn(pragmaticDnd, 'draggable').and.returnValue(noopCleanup);
    spyOn(pragmaticDnd, 'dropTargetForElements').and.returnValue(noopCleanup);
    spyOn(pragmaticDnd, 'combine').and.callFake((...cleanups) => () => {
      cleanups.forEach((cleanup) => cleanup());
    });

    Stimulus = Application.start();
    Stimulus.register('backlogs--dnd-item', BacklogsDndItemController);

    await nextFrame();

    const element = fixturesElement.querySelector<HTMLElement>('#story-1')!;
    element.dispatchEvent(new Event('turbo:morph-element'));

    expect(pragmaticDnd.draggable).toHaveBeenCalledTimes(2);
    expect(pragmaticDnd.dropTargetForElements).toHaveBeenCalledTimes(2);
  });

  it('only accepts drags that match its own itemType', async () => {
    fixturesElement.innerHTML = `
      <ul>
        <li
          id="story-1"
          data-controller="backlogs--dnd-item"
          data-backlogs--dnd-item-item-id-value="1"
          data-backlogs--dnd-item-item-type-value="story"
          data-backlogs--dnd-item-drop-url-value="/stories/1"></li>
      </ul>
    `;

    let dropTargetArgs:{ canDrop:(args:{ source:{ data:{ itemType?:string } } }) => boolean }|null = null;
    const noopCleanup = jasmine.createSpy('noopCleanup');

    spyOn(pragmaticDnd, 'draggable').and.returnValue(noopCleanup);
    spyOn(pragmaticDnd, 'dropTargetForElements').and.callFake((args) => {
      dropTargetArgs = args as typeof dropTargetArgs;

      return noopCleanup;
    });
    spyOn(pragmaticDnd, 'combine').and.callFake((...cleanups) => () => {
      cleanups.forEach((cleanup) => cleanup());
    });

    Stimulus = Application.start();
    Stimulus.register('backlogs--dnd-item', BacklogsDndItemController);

    await nextFrame();

    expect(dropTargetArgs).not.toBeNull();
    expect(dropTargetArgs!.canDrop({ source: { data: { itemType: 'story' } } })).toBe(true);
    expect(dropTargetArgs!.canDrop({ source: { data: { itemType: 'task' } } })).toBe(false);
    expect(dropTargetArgs!.canDrop({ source: { data: {} } })).toBe(false);
  });

  it('marks drag state on the document body while a drag is active and briefly after drop', async () => {
    fixturesElement.innerHTML = `
      <ul>
        <li
          id="story-1"
          data-controller="backlogs--dnd-item"
          data-backlogs--dnd-item-item-id-value="1"
          data-backlogs--dnd-item-item-type-value="story"
          data-backlogs--dnd-item-drop-url-value="/stories/1"></li>
      </ul>
    `;

    let draggableArgs:{
      onDragStart:(args:unknown) => void;
      onDrop:(args:unknown) => void;
    }|null = null;
    const noopCleanup = jasmine.createSpy('noopCleanup');

    spyOn(Date, 'now').and.returnValue(1_000);
    spyOn(pragmaticDnd, 'draggable').and.callFake((args) => {
      draggableArgs = args as typeof draggableArgs;

      return noopCleanup;
    });
    spyOn(pragmaticDnd, 'dropTargetForElements').and.returnValue(noopCleanup);
    spyOn(pragmaticDnd, 'combine').and.callFake((...cleanups) => () => {
      cleanups.forEach((cleanup) => cleanup());
    });

    Stimulus = Application.start();
    Stimulus.register('backlogs--dnd-item', BacklogsDndItemController);

    await nextFrame();

    expect(draggableArgs).not.toBeNull();

    draggableArgs!.onDragStart({});
    expect(document.body.dataset.backlogsDragging).toBe('true');

    draggableArgs!.onDrop({});
    expect(document.body.dataset.backlogsDragging).toBeUndefined();
    expect(document.body.dataset.backlogsSuppressClickUntil).toBe('1250');

  });
});

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

    expect(pragmaticDnd.draggable).toHaveBeenCalled();
    expect(pragmaticDnd.dropTargetForElements).toHaveBeenCalled();
    expect(pragmaticDnd.draggable).toHaveBeenCalledWith(jasmine.objectContaining({
      element: fixturesElement.querySelector('#story-1'),
    }));

    const controller = Stimulus.getControllerForElementAndIdentifier(
      fixturesElement.querySelector('#story-1')!,
      'backlogs--dnd-item',
    ) as BacklogsDndItemController;
    controller.disconnect();

    expect(draggableCleanup).toHaveBeenCalled();
    expect(dropTargetCleanup).toHaveBeenCalled();
  });

  it('reports before and after edges from the pointer position', async () => {
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

    let dropTargetArgs:{ getData:(args:{ input:{ clientY:number }; element:Element }) => Record<string, unknown> }|null = null;
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
      top: 100,
      height: 80,
    } as DOMRect);

    expect(dropTargetArgs).not.toBeNull();
    expect(dropTargetArgs!.getData({ input: { clientY: 110 }, element }).edge).toBe('before');
    expect(dropTargetArgs!.getData({ input: { clientY: 170 }, element }).edge).toBe('after');
  });

  it('re-registers the draggable after turbo morph on the same element', async () => {
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
});

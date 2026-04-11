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
import BacklogsDndListController from './dnd-list.controller';
import { pragmaticDnd } from './pragmatic-dnd';

const nextFrame = () => new Promise((resolve) => requestAnimationFrame(resolve));

describe('BacklogsDndListController', () => {
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

  it('registers a list drop target on connect and cleans it up on disconnect', async () => {
    fixturesElement.innerHTML = `
      <ul
        id="list"
        data-controller="backlogs--dnd-list"
        data-backlogs--dnd-list-list-id-value="sprint:1">
      </ul>
    `;

    const cleanup = jasmine.createSpy('cleanup');
    spyOn(pragmaticDnd, 'dropTargetForElements').and.returnValue(cleanup);

    Stimulus = Application.start();
    Stimulus.register('backlogs--dnd-list', BacklogsDndListController);

    await nextFrame();

    expect(pragmaticDnd.dropTargetForElements).toHaveBeenCalled();

    const controller = Stimulus.getControllerForElementAndIdentifier(
      fixturesElement.querySelector('#list')!,
      'backlogs--dnd-list',
    ) as BacklogsDndListController;
    controller.disconnect();

    expect(cleanup).toHaveBeenCalled();
  });
});

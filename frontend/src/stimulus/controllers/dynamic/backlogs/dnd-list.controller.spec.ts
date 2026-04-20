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
import DndListController from './dnd-list.controller';

const nextFrame = () => new Promise((resolve) => requestAnimationFrame(resolve));

describe('Backlogs::DndListController', () => {
  let Stimulus:Application;
  let fixturesElement:HTMLElement;

  const listTemplate = `
    <div
      id="inbox-list-shell"
      data-controller="backlogs--dnd-list"
      data-backlogs--dnd-list-target-id-value="inbox"
    >
      <ul id="inbox-list">
        <li id="work_package_1" data-controller="backlogs--item" data-draggable-id="1"></li>
        <li id="inbox-empty" data-empty-list-item="true"></li>
        <li id="inbox-show-more" data-draggable-id="99"></li>
      </ul>
    </div>
  `;

  const emptyListTemplate = `
    <div
      id="empty-list-shell"
      data-controller="backlogs--dnd-list"
      data-backlogs--dnd-list-target-id-value="inbox"
    >
      <ul id="empty-list">
        <li id="empty-state" data-empty-list-item="true"></li>
      </ul>
    </div>
  `;

  const collapsedSprintTemplate = `
    <section
      id="collapsed-sprint-shell"
      data-controller="backlogs--dnd-list"
      data-backlogs--dnd-list-target-id-value="sprint:5"
    >
      <header id="collapsed-sprint-header" data-collapsed="true"></header>
      <ul id="collapsed-sprint-list" hidden></ul>
    </section>
  `;

  function appendTemplate(html:string) {
    const template = document.createElement('template');
    template.innerHTML = html.trim();
    fixturesElement.appendChild(template.content.cloneNode(true));
  }

  function controllerFor(elementId:string):DndListController {
    return Stimulus.getControllerForElementAndIdentifier(
      document.getElementById(elementId)!,
      'backlogs--dnd-list',
    ) as DndListController;
  }

  beforeEach(() => {
    fixturesElement = document.createElement('div');
    document.body.appendChild(fixturesElement);
  });

  beforeEach(async () => {
    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('backlogs--dnd-list', DndListController);
    await nextFrame();
  });

  afterEach(() => {
    fixturesElement.remove();
    Stimulus.stop();
  });

  it('exposes the list identity and item container', async () => {
    appendTemplate(listTemplate);
    await nextFrame();

    const controller = controllerFor('inbox-list-shell');

    expect(controller.targetId).toBe('inbox');
    expect(controller.dropZoneElement.id).toBe('inbox-list-shell');
    expect(controller.itemContainer.id).toBe('inbox-list');
  });

  it('ignores non-item rows when collecting draggable items', async () => {
    appendTemplate(listTemplate);
    await nextFrame();

    const controller = controllerFor('inbox-list-shell');

    expect(controller.draggableItems.map((element:HTMLElement) => element.id)).toEqual(['work_package_1']);
    expect(controller.isEmpty).toBeFalse();
  });

  it('keeps empty lists droppable', async () => {
    appendTemplate(emptyListTemplate);
    await nextFrame();

    const controller = controllerFor('empty-list-shell');

    expect(controller.dropZoneElement.id).toBe('empty-list-shell');
    expect(controller.itemContainer.id).toBe('empty-list');
    expect(controller.draggableItems).toEqual([]);
    expect(controller.isEmpty).toBeTrue();
  });

  it('keeps collapsed sprint shells droppable', async () => {
    appendTemplate(collapsedSprintTemplate);
    await nextFrame();

    const controller = controllerFor('collapsed-sprint-shell');

    expect(controller.targetId).toBe('sprint:5');
    expect(controller.dropZoneElement.id).toBe('collapsed-sprint-shell');
    expect(controller.itemContainer.id).toBe('collapsed-sprint-list');
    expect(controller.isEmpty).toBeTrue();
  });
});

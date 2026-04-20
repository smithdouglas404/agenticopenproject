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
      data-backlogs--dnd-list-target="container"
    >
      <div id="work_package_1" data-backlogs--dnd-list-target="item" data-draggable-id="1"></div>
      <div id="work_package_2" data-backlogs--dnd-list-target="item" data-draggable-id="2"></div>
      <div id="inbox-empty" data-empty-list-item="true"></div>
      <div id="inbox-show-more" data-backlogs--dnd-list-target="item"></div>
      <div id="legacy-target" data-controller="backlogs--item" data-draggable-id="99"></div>
    </div>
  `;

  const emptyListTemplate = `
    <div
      id="empty-list-shell"
      data-controller="backlogs--dnd-list"
      data-backlogs--dnd-list-target-id-value="inbox"
      data-backlogs--dnd-list-target="container"
    >
      <div id="empty-state" data-empty-list-item="true"></div>
    </div>
  `;

  const collapsedSprintTemplate = `
    <section
      id="collapsed-sprint-shell"
      data-controller="backlogs--dnd-list"
      data-backlogs--dnd-list-target-id-value="sprint:5"
      data-backlogs--dnd-list-target="container"
    >
      <header id="collapsed-sprint-header" data-collapsed="true"></header>
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
    expect(controller.containerTarget.id).toBe('inbox-list-shell');
    expect(controller.itemContainer.id).toBe('inbox-list-shell');
  });

  it('ignores non-item rows when collecting draggable items', async () => {
    appendTemplate(listTemplate);
    await nextFrame();

    const controller = controllerFor('inbox-list-shell');

    expect(controller.itemTargets.map((element:HTMLElement) => element.id)).toEqual([
      'work_package_1',
      'work_package_2',
      'inbox-show-more',
    ]);

    expect(controller.draggableItems.map((element:HTMLElement) => element.id)).toEqual([
      'work_package_1',
      'work_package_2',
    ]);

    expect(controller.isEmpty).toBeFalse();
  });

  it('keeps empty lists droppable', async () => {
    appendTemplate(emptyListTemplate);
    await nextFrame();

    const controller = controllerFor('empty-list-shell');

    expect(controller.dropZoneElement.id).toBe('empty-list-shell');
    expect(controller.itemContainer.id).toBe('empty-list-shell');
    expect(controller.draggableItems).toEqual([]);
    expect(controller.isEmpty).toBeTrue();
  });

  it('keeps collapsed sprint shells droppable', async () => {
    appendTemplate(collapsedSprintTemplate);
    await nextFrame();

    const controller = controllerFor('collapsed-sprint-shell');

    expect(controller.targetId).toBe('sprint:5');
    expect(controller.dropZoneElement.id).toBe('collapsed-sprint-shell');
    expect(controller.itemContainer.id).toBe('collapsed-sprint-shell');
    expect(controller.isEmpty).toBeTrue();
  });

  it('suppresses initial sync on connect and reconnect, then coalesces later churn', async () => {
    appendTemplate(listTemplate);
    await nextFrame();

    const controller = controllerFor('inbox-list-shell');
    const events:Event[] = [];

    fixturesElement.addEventListener('backlogs:dnd-list:changed', (event) => {
      events.push(event);
    });

    expect(events.length).toBe(0);

    const shell = controller.element;
    shell.remove();
    fixturesElement.appendChild(shell);

    await nextFrame();

    expect(events.length).toBe(0);

    controller.element.insertAdjacentHTML('beforeend', '<div id="reconnected-item" data-backlogs--dnd-list-target="item" data-draggable-id="7"></div>');
    controller.element.insertAdjacentHTML('beforeend', '<div id="reconnected-item-2" data-backlogs--dnd-list-target="item" data-draggable-id="8"></div>');

    await nextFrame();

    expect(events.length).toBe(1);
    expect(events[0].target).toBe(controller.element);
  });

  it('emits a bubbling change event when item targets change in the DOM', async () => {
    appendTemplate(emptyListTemplate);
    await nextFrame();

    const controller = controllerFor('empty-list-shell');
    const events:Event[] = [];

    fixturesElement.addEventListener('backlogs:dnd-list:changed', (event) => {
      events.push(event);
    });

    controller.element.insertAdjacentHTML('beforeend', '<div id="new-item" data-backlogs--dnd-list-target="item" data-draggable-id="7"></div>');

    await nextFrame();

    expect(events.length).toBe(1);
    expect(events[0].target).toBe(controller.element);
  });

  it('does not rely on controller queries for draggable items', async () => {
    const template = `
      <div
        id="target-only-shell"
        data-controller="backlogs--dnd-list"
        data-backlogs--dnd-list-target-id-value="inbox"
        data-backlogs--dnd-list-target="container"
      >
        <div id="target-only-item" data-backlogs--dnd-list-target="item" data-draggable-id="1"></div>
        <div id="controller-only-item" data-controller="backlogs--item" data-draggable-id="2"></div>
      </div>
    `;

    appendTemplate(template);
    await nextFrame();

    const controller = controllerFor('target-only-shell');

    expect(controller.draggableItems.map((element:HTMLElement) => element.id)).toEqual(['target-only-item']);
  });
});

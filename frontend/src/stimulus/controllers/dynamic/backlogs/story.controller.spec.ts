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
import StoryController from './story.controller';

const nextFrame = () => new Promise((resolve) => requestAnimationFrame(resolve));

describe('StoryController', () => {
  let Stimulus:Application;
  let fixturesElement:HTMLElement;

  beforeEach(() => {
    fixturesElement = document.createElement('div');
    document.body.appendChild(fixturesElement);
    jasmine.clock().install();
  });

  beforeEach(async () => {
    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('backlogs--story', StoryController);
    await nextFrame();
  });

  afterEach(() => {
    fixturesElement.remove();
    Stimulus.stop();
    jasmine.clock().uninstall();
  });

  function appendTemplate(html:string) {
    const template = document.createElement('template');
    template.innerHTML = html.trim();
    fixturesElement.appendChild(template.content.cloneNode(true));
  }

  function appendStoryTemplate() {
    appendTemplate(`
      <li
        data-controller="backlogs--story"
        data-backlogs--story-id-value="33"
        data-backlogs--story-split-url-value="/projects/your-scrum-project/backlogs/backlog/details/33"
        data-backlogs--story-full-url-value="/work_packages/33"
        data-backlogs--story-selected-class="Box-row--blue"
      >
        <div class="DragHandle" role="button" tabindex="0" aria-label="Move Develop v1.1"></div>
        <span class="story-subject">Develop v1.1</span>
      </li>
    `);
  }

  function getController():StoryController {
    return Stimulus.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller="backlogs--story"]')!,
      'backlogs--story',
    ) as StoryController;
  }

  it('opens the split pane when clicking the row body', async () => {
    appendStoryTemplate();
    await nextFrame();

    const controller = getController();
    const openSplitPaneSpy = spyOn(controller as never, 'openSplitPane' as never);
    const subject = document.querySelector<HTMLElement>('.story-subject')!;

    subject.click();
    jasmine.clock().tick(251);

    expect(openSplitPaneSpy).toHaveBeenCalledTimes(1);
  });

  it('does not open the split pane when clicking the drag handle', async () => {
    appendStoryTemplate();
    await nextFrame();

    const controller = getController();
    const openSplitPaneSpy = spyOn(controller as never, 'openSplitPane' as never);
    const handle = document.querySelector<HTMLElement>('.DragHandle')!;

    handle.click();
    jasmine.clock().tick(251);

    expect(openSplitPaneSpy).not.toHaveBeenCalled();
  });
});

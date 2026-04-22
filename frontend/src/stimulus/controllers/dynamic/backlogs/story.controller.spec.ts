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
    jasmine.clock().install();
    fixturesElement = document.createElement('div');
    document.body.appendChild(fixturesElement);
  });

  afterEach(() => {
    Stimulus?.stop();
    fixturesElement.remove();
    delete document.body.dataset.backlogsDragging;
    delete document.body.dataset.backlogsSuppressClickUntil;
    jasmine.clock().uninstall();
  });

  async function startWithFixture() {
    fixturesElement.innerHTML = `
      <article
        id="story-1"
        data-controller="backlogs--story"
        data-backlogs--story-id-value="1"
        data-backlogs--story-split-url-value="/work_packages/1/details"
        data-backlogs--story-full-url-value="/work_packages/1"
        data-backlogs--story-selected-class="selected">
        <span>Story</span>
      </article>
    `;

    Stimulus = Application.start();
    Stimulus.register('backlogs--story', StoryController);

    await nextFrame();
  }

  it('opens the split pane on click', async () => {
    await startWithFixture();

    const element = fixturesElement.querySelector<HTMLElement>('#story-1')!;
    const controller = Stimulus.getControllerForElementAndIdentifier(
      element,
      'backlogs--story',
    ) as StoryController & { openSplitPane():void };
    const openSplitPaneSpy = spyOn(controller, 'openSplitPane');

    element.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    jasmine.clock().tick(250);

    expect(openSplitPaneSpy).toHaveBeenCalled();
  });

  it('suppresses split-pane clicks after pointer movement crosses the drag-intent threshold', async () => {
    await startWithFixture();

    const element = fixturesElement.querySelector<HTMLElement>('#story-1')!;
    const controller = Stimulus.getControllerForElementAndIdentifier(
      element,
      'backlogs--story',
    ) as StoryController & { openSplitPane():void };
    const openSplitPaneSpy = spyOn(controller, 'openSplitPane');

    element.dispatchEvent(new PointerEvent('pointerdown', {
      bubbles: true,
      button: 0,
      clientX: 10,
      clientY: 10,
    }));
    element.dispatchEvent(new PointerEvent('pointermove', {
      bubbles: true,
      buttons: 1,
      clientX: 18,
      clientY: 18,
    }));
    element.dispatchEvent(new PointerEvent('pointerup', {
      bubbles: true,
      button: 0,
      clientX: 18,
      clientY: 18,
    }));
    element.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    jasmine.clock().tick(250);

    expect(openSplitPaneSpy).not.toHaveBeenCalled();
  });

  it('suppresses split-pane clicks while a drag is active or has just completed', async () => {
    await startWithFixture();

    const element = fixturesElement.querySelector<HTMLElement>('#story-1')!;
    const controller = Stimulus.getControllerForElementAndIdentifier(
      element,
      'backlogs--story',
    ) as StoryController & { openSplitPane():void };
    const openSplitPaneSpy = spyOn(controller, 'openSplitPane');

    document.body.dataset.backlogsDragging = 'true';
    element.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    jasmine.clock().tick(250);

    delete document.body.dataset.backlogsDragging;
    document.body.dataset.backlogsSuppressClickUntil = String(Date.now() + 250);
    element.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    jasmine.clock().tick(250);

    expect(openSplitPaneSpy).not.toHaveBeenCalled();
  });
});

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
import * as Turbo from '@hotwired/turbo';
import ItemController from './item.controller';

const nextFrame = () => new Promise((resolve) => requestAnimationFrame(resolve));
const wait = (ms:number) => new Promise((resolve) => window.setTimeout(resolve, ms));

describe('Backlogs::ItemController', () => {
  let Stimulus:Application;
  let fixturesElement:HTMLElement;
  let visitSpy:jasmine.Spy<(location:string, options?:unknown) => void>;

  const originalLocation = window.location.href;

  const cardTemplate = `
    <div
      id="work_package_42"
      class="Box-row"
      tabindex="0"
      data-controller="backlogs--item"
      data-backlogs--item-id-value="42"
      data-backlogs--item-split-url-value="/projects/demo/backlogs/backlog/details/42"
      data-backlogs--item-full-url-value="/work_packages/42"
      data-backlogs--item-selected-class="Box-row--blue"
    >
      <button id="menu-button" type="button">Menu</button>
      <a id="subject-link" href="/work_packages/42">Subject</a>
      <input id="edit-field" type="text" />
      <span id="card-content">Card content</span>
    </div>
  `;

  function appendTemplate(html:string) {
    const template = document.createElement('template');
    template.innerHTML = html.trim();
    fixturesElement.appendChild(template.content.cloneNode(true));
  }

  function cardElement():HTMLElement {
    return document.getElementById('work_package_42')!;
  }

  beforeEach(() => {
    fixturesElement = document.createElement('div');
    document.body.appendChild(fixturesElement);
    visitSpy = spyOn(Turbo.session as unknown as { visit:(location:string, options?:unknown) => void }, 'visit');
  });

  beforeEach(async () => {
    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('backlogs--item', ItemController);
    await nextFrame();
  });

  afterEach(() => {
    window.history.replaceState({}, '', originalLocation);
    fixturesElement.remove();
    Stimulus?.stop();
  });

  it('opens the split view on click', async () => {
    appendTemplate(cardTemplate);
    await nextFrame();

    cardElement().click();
    await wait(260);

    expect(visitSpy).toHaveBeenCalledOnceWith('/projects/demo/backlogs/backlog/details/42', {
      frame: 'content-bodyRight',
      action: 'advance',
    });
  });

  it('opens the full view on double click', async () => {
    appendTemplate(cardTemplate);
    await nextFrame();

    cardElement().dispatchEvent(new MouseEvent('dblclick', { bubbles: true }));

    expect(visitSpy).toHaveBeenCalledOnceWith('/work_packages/42', { frame: '_top' });
  });

  it('opens the split view on Enter', async () => {
    appendTemplate(cardTemplate);
    await nextFrame();

    cardElement().dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, key: 'Enter' }));

    expect(visitSpy).toHaveBeenCalledOnceWith('/projects/demo/backlogs/backlog/details/42', {
      frame: 'content-bodyRight',
      action: 'advance',
    });
  });

  it('opens the full view on Shift+Enter', async () => {
    appendTemplate(cardTemplate);
    await nextFrame();

    cardElement().dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, key: 'Enter', shiftKey: true }));

    expect(visitSpy).toHaveBeenCalledOnceWith('/work_packages/42', { frame: '_top' });
  });

  it('ignores interactive descendants for click handling', async () => {
    appendTemplate(cardTemplate);
    await nextFrame();

    document.getElementById('menu-button')!.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    await wait(260);

    expect(visitSpy).not.toHaveBeenCalled();
  });

  it('does not open the split view after pointer movement beyond the drag threshold', async () => {
    appendTemplate(cardTemplate);
    await nextFrame();

    cardElement().dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, clientX: 10, clientY: 10 }));
    cardElement().dispatchEvent(new PointerEvent('pointermove', { bubbles: true, clientX: 24, clientY: 10 }));
    cardElement().click();
    await wait(260);

    expect(visitSpy).not.toHaveBeenCalled();
  });

  it('syncs aria-current and the selected class from the current URL', async () => {
    window.history.replaceState({}, '', '/projects/demo/backlogs/backlog/details/42');

    appendTemplate(cardTemplate);
    await nextFrame();

    expect(cardElement().classList.contains('Box-row--blue')).toBeTrue();
    expect(cardElement().getAttribute('aria-current')).toBe('true');

    document.dispatchEvent(new CustomEvent('turbo:visit', {
      detail: { url: '/projects/demo/backlogs/backlog/details/99' },
    }));

    expect(cardElement().classList.contains('Box-row--blue')).toBeFalse();
    expect(cardElement().hasAttribute('aria-current')).toBeFalse();
  });
});

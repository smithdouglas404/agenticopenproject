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
import CheckAllController from './check-all.controller';
import CheckableController from './checkable.controller';

describe('CheckAllController', () => {
  let Stimulus:Application;
  let fixturesElement:HTMLElement;

  beforeAll(() => {
    Stimulus = Application.start();
    // Stimulus.debug = true;
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('checkable', CheckableController);
    Stimulus.register('check-all', CheckAllController);
  });

  const checkAllTemplate = `
    <div data-controller="check-all" data-check-all-checkable-outlet="#checkables">
      <button id="check-all" data-action="check-all#checkAll">Check all</button>
      <button id="uncheck-all" data-action="check-all#uncheckAll">Check all</button>
    </div>
  `;

  const checkableTemplate = `
    <div id="checkables" data-controller="checkable">
      <input type="checkbox" data-checkable-target="checkbox">
      <input type="checkbox" data-checkable-target="checkbox">
      <input type="checkbox" data-checkable-target="checkbox">
    </div>
  `;


  beforeEach(() => {
    fixturesElement = document.createElement('div');
    document.body.appendChild(fixturesElement);
  });

  function appendTemplate(html:string) {
    const template = document.createElement('template');
    template.innerHTML = html.trim();
    fixturesElement.appendChild(template.content.cloneNode(true));
  }

  describe('without checkable controller', () => {
    it('does nothing', () => {
      appendTemplate(checkAllTemplate);

      document.getElementById('check-all')!.click();
      document.getElementById('uncheck-all')!.click();
    });
  });

  describe('with checkable controller', () => {
    it('toggles checkboxes', async () => {
      appendTemplate(checkableTemplate);
      appendTemplate(checkAllTemplate);

      // Allow Stimulus to connect controllers and resolve outlets
      await new Promise((resolve) => setTimeout(resolve, 0));

      const inputs = Array.from(document.querySelectorAll<HTMLInputElement>('input[type="checkbox"]'));

      expect(inputs).toHaveSize(3);
      expect(inputs.every((i) => !i.checked)).toBeTrue();

      document.getElementById('check-all')!.click();

      expect(inputs.every((i) => i.checked)).toBeTrue();

      document.getElementById('uncheck-all')!.click();

      expect(inputs.every((i) => !i.checked)).toBeTrue();
    });
  });

  afterEach(() => {
    fixturesElement.remove();
  });

  afterAll(() => {
    Stimulus.stop();
  });
});

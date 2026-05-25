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

import PageController from './page.controller';

describe('Reporting PageController filters', () => {
  let controller:PageController;
  let fixturesElement:HTMLElement;

  beforeEach(() => {
    controller = Object.create(PageController.prototype) as PageController;
    fixturesElement = document.createElement('div');
    document.body.appendChild(fixturesElement);
  });

  afterEach(() => {
    fixturesElement.remove();
  });

  it('falls back to the filter data attribute when the remove input is blank', () => {
    fixturesElement.innerHTML = `
      <li data-filter-name="subject">
        <div id="rm_box_subject">
          <input type="hidden" name="fields[]" value="">
        </div>
      </li>
    `;

    const removeBox = fixturesElement.querySelector<HTMLElement>('#rm_box_subject')!;
    const removedFilters:string[] = [];
    Object.assign(controller, {
      filters: {
        remove_filter(filter:string) {
          removedFilters.push(filter);
        },
      },
    });

    controller.removeFilter({
      preventDefault: () => undefined,
      currentTarget: removeBox,
    } as unknown as MouseEvent);

    expect(removedFilters).toEqual(['subject']);
  });
});

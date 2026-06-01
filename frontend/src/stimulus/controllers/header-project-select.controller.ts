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

import { Controller } from '@hotwired/stimulus';

const STORAGE_KEY = 'openProject-project-select-display-mode';
const VALID_FILTER_MODES = new Set(['all', 'favorited']);
const NON_DEFAULT_FILTER_MODES = new Set(['favorited']);

export default class HeaderProjectSelectController extends Controller {
  connect():void {
    const stored = window.OpenProject.guardedLocalStorage(STORAGE_KEY);
    if (stored && NON_DEFAULT_FILTER_MODES.has(stored)) {
      // Defer until after all Stimulus/Catalyst controllers have connected (including
      // filterable-tree-view), so its click listener is already set up when
      // we programmatically activate the stored filter mode.
      setTimeout(() => {
        this.element
          .querySelector<HTMLElement>(`[data-name="${stored}"]`)
          ?.click();
      }, 0);
    }

    this.element.addEventListener('click', this.onFilterModeClick);
  }

  disconnect():void {
    this.element.removeEventListener('click', this.onFilterModeClick);
  }

  private onFilterModeClick = (event:MouseEvent):void => {
    const button = (event.target as HTMLElement).closest<HTMLElement>('[data-name]');
    if (button?.dataset.name && VALID_FILTER_MODES.has(button.dataset.name)) {
      window.OpenProject.guardedLocalStorage(STORAGE_KEY, button.dataset.name);
    }
  };
}

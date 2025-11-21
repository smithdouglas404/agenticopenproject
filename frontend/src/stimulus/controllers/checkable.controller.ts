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

import { Controller, ActionEvent } from '@hotwired/stimulus';
import invariant from 'tiny-invariant';

export default class CheckableController extends Controller<HTMLElement> {
  static targets = ['checkbox'];

  declare readonly checkboxTargets:HTMLInputElement[];

  checkAll(event:Event) {
    event.preventDefault();
    this.toggleChecked(this.checkboxTargets, true);
  }

  uncheckAll(event:Event) {
    event.preventDefault();
    this.toggleChecked(this.checkboxTargets, false);
  }

  toggleAll(event:Event) {
    event.preventDefault();

    this.toggleChecked(this.checkboxTargets);
  }

  // Generic selection toggle used by table-like controllers. It looks up
  // `data-` attributes on checkboxes and toggles the subset matching the
  // provided key/value pair.
  toggleSelection(event:ActionEvent) {
    event.preventDefault();

    const { key, value } = event.params as { key:string; value:unknown };
    invariant(key, 'toggleSelection requires a key param');
    invariant(value, 'toggleSelection requires value param');

    // eslint-disable-next-line @typescript-eslint/no-base-to-string
    const checkboxes = this.checkboxTargets.filter((checkbox) => checkbox.dataset[key] === value.toString());
    this.toggleChecked(checkboxes);
  }

  private toggleChecked(checkboxes:HTMLInputElement[], checked?:boolean) {
    // If all are checked -> uncheck all.
    // If mixed or none checked -> check all.
    const allChecked = checkboxes.every((checkbox) => checkbox.checked);
    checked ??= !allChecked;

    checkboxes.forEach((checkbox) => {
      checkbox.checked = checked;
      checkbox.dispatchEvent(new Event('input', { bubbles: false, cancelable: true }));
    });
  }
}

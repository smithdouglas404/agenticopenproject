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
import dragula from 'dragula';

export default class CustomFieldsController extends Controller {
  static targets = [
    'format',
    'dragContainer',
    'submitButton',

    'template',
    'table',
    'customOptionDefaults',
    'customOptionRow',

    'enterpriseBanner',
  ];

  static values = {
    itemCount: Number,
    hierarchyEnabled: Boolean,
    format: String,
  };

  declare itemCountValue:number;
  declare readonly formatValue:string;
  declare readonly hierarchyEnabledValue:boolean;

  declare readonly formatTarget:HTMLInputElement;
  declare readonly dragContainerTarget:HTMLElement;
  declare readonly hasDragContainerTarget:boolean;
  declare readonly submitButtonTarget:HTMLButtonElement;
  declare readonly hasSubmitButtonTarget:boolean;

  declare readonly templateTarget:HTMLElement;
  declare readonly tableTarget:HTMLTableElement;

  declare readonly customOptionDefaultsTargets:HTMLInputElement[];
  declare readonly enterpriseBannerTarget:HTMLElement;

  get customOptionRows() {
    return [...this.tableTarget.tBodies[0].rows];
  }

  connect() {
    if (this.hasDragContainerTarget) {
      this.setupDragAndDrop();
    }

    this.adaptInputsToFormat(this.formatValue);
  }

  moveRowUp(event:{ target:HTMLElement }) {
    const row = event.target.closest('tr')!;
    const idx = this.customOptionRows.indexOf(row);
    if (idx > 0) {
      this.customOptionRows[idx - 1].before(row);
    }

    return false;
  }

  moveRowDown(event:{ target:HTMLElement }) {
    const row = event.target.closest('tr')!;
    const idx = this.customOptionRows.indexOf(row);
     
    if (idx < this.customOptionRows.length - 1) {
      this.customOptionRows[idx + 1].after(row);
    }

    return false;
  }

  moveRowToTheTop(event:{ target:HTMLElement }) {
    const row = event.target.closest('tr')!;
    const first = this.customOptionRows[0];

    if (first && first !== row) {
      first.before(row);
    }

    return false;
  }

  moveRowToTheBottom(event:{ target:HTMLElement }) {
    const row = event.target.closest('tr')!;
    const last = this.customOptionRows[this.customOptionRows.length - 1];

    if (last && last !== row) {
      last.after(row);
    }

    return false;
  }

  removeOption(event:MouseEvent) {
    const self = event.target as HTMLButtonElement;
    const row = self.closest('tr');

    if (row && this.customOptionRows.length > 1) {
      row.remove();
    }

    event.preventDefault();
    event.stopImmediatePropagation();
  
    return true; // send off deletion
  }

  addOption() {
    const newRow = this.templateTarget.cloneNode(true);
    this.tableTarget.append(newRow);

    const addedRow = this.tableTarget.lastChild as HTMLElement;
    addedRow.outerHTML = addedRow.outerHTML.replace(/INDEX/g, this.itemCountValue.toString());

    this.itemCountValue += 1;
  }

  uncheckOtherDefaults(event:{ target:HTMLElement }) {
    const cb = event.target as HTMLInputElement;

    if (cb.checked) {
      const multi = undefined; // FIXME this.multiSelectTargets[0] as HTMLInputElement|undefined;

      // if (multi?.checked === false) {
      //   this.customOptionDefaultsTargets.forEach((el) => (el.checked = false));
      //   cb.checked = true;
      // }
    }
  }

  checkOnlyOne(event:{ target:HTMLElement }) {
    const cb = event.target as HTMLInputElement;

    if (!cb.checked) {
      this.customOptionDefaultsTargets
        .filter((el) => el.checked)
        .slice(1)
        .forEach((el) => (el.checked = false));
    }
  }

  private setupDragAndDrop() {
    // Make custom fields draggable
    const drake = dragula([this.dragContainerTarget], {
      isContainer: () => false,
      moves: (el, source, handle:HTMLElement) => handle.classList.contains('dragula-handle'),
      accepts: () => true,
      invalid: () => false,
      direction: 'vertical',
      copy: false,
      copySortSource: false,
      revertOnSpill: true,
      removeOnSpill: false,
      mirrorContainer: this.dragContainerTarget,
      ignoreInputTextSelection: true,
    });

    // Setup autoscroll
    void window.OpenProject.getPluginContext().then((pluginContext) => {
      new pluginContext.classes.DomAutoscrollService(
        [
          document.getElementById('content-body')!,
        ],
        {
          margin: 25,
          maxSpeed: 10,
          scrollWhenOutside: true,
          autoScroll: () => drake.dragging,
        },
      );
    });
  }

  private setActive(elements:HTMLElement[], active:boolean) {
    elements.forEach((element) => {
      element.hidden = !active;
      element
        .querySelectorAll<HTMLInputElement>('input, textarea')
        .forEach((input) => {
          input.disabled = !active;
        });
    });
  }

  private adaptInputsToFormat(format:string) {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = format === 'hierarchy' && !this.hierarchyEnabledValue;
    }


  }
}

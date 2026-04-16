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
import dragula, { Drake } from 'dragula';
import type { DomAutoscrollService } from 'core-app/shared/helpers/drag-and-drop/dom-autoscroll.service';

const EMPTY_GROUP_KEY = '__empty';

interface TypeFormAttribute {
  key:string;
  translation:string;
  is_cf:boolean;
}

interface TypeGroup {
  key:string|null|undefined;
  name:string;
  type:'attribute'|'query';
  attributes:TypeFormAttribute[]|null;
  query?:string|null;
}

export default class TypeFormConfigurationController extends Controller {
  static targets = ['sectionsContainer', 'inactiveContainer'];

  declare readonly sectionsContainerTarget:HTMLElement;
  declare readonly inactiveContainerTarget:HTMLElement;

  static values = {
    noFilterQuery: String,
    eeAvailable: Boolean,
  };

  declare readonly noFilterQueryValue:string;
  declare readonly eeAvailableValue:boolean;

  private sectionsDrake:Drake|null = null;
  private attributesDrake:Drake|null = null;
  private autoscroll:DomAutoscrollService|null = null;

  connect() {
    this.initDrake();
    this.setupFormSubmit();
  }

  disconnect() {
    this.sectionsDrake?.destroy();
    this.sectionsDrake = null;
    this.attributesDrake?.destroy();
    this.attributesDrake = null;
    this.autoscroll?.destroy();
    this.autoscroll = null;
  }

  // ---- Subheader actions ----

  addAttributeSection(event:Event) {
    event.preventDefault();
    const section = this.buildSectionElement('attribute', '');
    this.sectionsContainerTarget.prepend(section);
    const ul = section.querySelector<HTMLElement>('ul.Box-list');
    if (ul && this.attributesDrake) {
      this.attributesDrake.containers.push(ul);
    }
    this.openRename(section);
  }

  addQuerySection(event:Event) {
    event.preventDefault();
    const section = this.buildSectionElement('query', '');
    this.sectionsContainerTarget.prepend(section);
    this.openRename(section);
  }

  confirmReset(event:Event) {
    event.preventDefault();

    const form = this.element.closest<HTMLFormElement>('form');
    if (!form) return;

    const hiddenField = form.querySelector<HTMLInputElement>('.admin-type-form--hidden-field');
    if (hiddenField) {
      hiddenField.value = JSON.stringify([]);
    }

    form.removeEventListener('submit', this.formSubmitHandler);
    form.requestSubmit();
  }

  // ---- Filter ----

  filterInactives(event:Event) {
    const input = event.currentTarget as HTMLInputElement;
    const query = input.value.trim().toLowerCase();
    const inactiveUl = this.inactiveContainerTarget.querySelector<HTMLElement>('ul.Box-list');
    if (!inactiveUl) return;

    Array.from(inactiveUl.querySelectorAll<HTMLElement>('li[data-attr-key]')).forEach((row) => {
      const translation = (row.dataset.attrTranslation || '').toLowerCase();
      (row as HTMLElement).style.display = (query === '' || translation.includes(query)) ? '' : 'none';
    });
  }

  // ---- Section rename ----

  startRenameSection(event:Event) {
    event.preventDefault();
    const section = this.findSection(event);
    if (!section) return;
    this.openRename(section);
  }

  saveRenameSection(event:Event) {
    event.preventDefault();
    event.stopPropagation();

    const input = event.currentTarget as HTMLInputElement;
    const section = input.closest<HTMLElement>('[data-group-type]');
    if (!section) return;

    const newName = input.value.trim();
    if (!newName) return;

    section.dataset.groupName = newName;
    section.dataset.groupKey = '';

    const nameDisplay = section.querySelector<HTMLElement>('.section-name-display');
    if (nameDisplay) nameDisplay.textContent = newName;

    input.style.display = 'none';
    if (nameDisplay) nameDisplay.style.display = '';
  }

  cancelRenameSection(event:Event) {
    const input = event.currentTarget as HTMLInputElement;
    const section = input.closest<HTMLElement>('[data-group-type]');
    if (!section) return;

    input.value = section.dataset.groupName || '';
    input.style.display = 'none';

    const nameDisplay = section.querySelector<HTMLElement>('.section-name-display');
    if (nameDisplay) nameDisplay.style.display = '';
  }

  // ---- Section moves ----

  moveSectionTop(event:Event) {
    event.preventDefault();
    const section = this.findSection(event);
    if (!section?.parentElement) return;
    section.parentElement.prepend(section);
  }

  moveSectionUp(event:Event) {
    event.preventDefault();
    const section = this.findSection(event);
    if (!section?.previousElementSibling) return;
    section.parentElement!.insertBefore(section, section.previousElementSibling);
  }

  moveSectionDown(event:Event) {
    event.preventDefault();
    const section = this.findSection(event);
    if (!section?.nextElementSibling) return;
    section.parentElement!.insertBefore(section.nextElementSibling, section);
  }

  moveSectionBottom(event:Event) {
    event.preventDefault();
    const section = this.findSection(event);
    if (!section?.parentElement) return;
    section.parentElement.append(section);
  }

  // ---- Section delete ----

  deleteSection(event:Event) {
    event.preventDefault();
    const section = this.findSection(event);
    if (!section) return;

    if (section.dataset.groupType === 'attribute') {
      const inactiveUl = this.inactiveContainerTarget.querySelector<HTMLElement>('ul.Box-list');
      if (inactiveUl) {
        section.querySelectorAll<HTMLElement>('li[data-attr-key]').forEach((row) => {
          row.querySelector<HTMLElement>('.js-row-actions')?.remove();
          inactiveUl.appendChild(row);
        });
      }
    }

    const ul = section.querySelector<HTMLElement>('ul.Box-list');
    if (ul && this.attributesDrake) {
      const idx = this.attributesDrake.containers.indexOf(ul);
      if (idx !== -1) this.attributesDrake.containers.splice(idx, 1);
    }

    section.remove();
  }

  // ---- Row moves ----

  moveRowTop(event:Event) {
    event.preventDefault();
    const row = this.findRow(event);
    if (!row?.parentElement) return;
    const firstAttrRow = row.parentElement.querySelector<HTMLElement>('li[data-attr-key]');
    if (firstAttrRow && firstAttrRow !== row) {
      row.parentElement.insertBefore(row, firstAttrRow);
    }
  }

  moveRowUp(event:Event) {
    event.preventDefault();
    const row = this.findRow(event);
    if (!row) return;
    const prev = this.previousAttrRow(row);
    if (prev) row.parentElement!.insertBefore(row, prev);
  }

  moveRowDown(event:Event) {
    event.preventDefault();
    const row = this.findRow(event);
    if (!row) return;
    const next = this.nextAttrRow(row);
    if (next) row.parentElement!.insertBefore(next, row);
  }

  moveRowBottom(event:Event) {
    event.preventDefault();
    const row = this.findRow(event);
    if (!row?.parentElement) return;
    row.parentElement.appendChild(row);
  }

  // ---- Row delete ----

  deleteRow(event:Event) {
    event.preventDefault();
    const row = this.findRow(event);
    if (!row) return;

    row.querySelector<HTMLElement>('.js-row-actions')?.remove();

    const inactiveUl = this.inactiveContainerTarget.querySelector<HTMLElement>('ul.Box-list');
    if (inactiveUl) inactiveUl.appendChild(row);
  }

  // ---- Edit query ----

  editQuery(_event:Event) {
    // Query editing is handled by the external Angular modal service.
    // This will be wired up once the query editor is migrated.
  }

  // ---- Private helpers ----

  private formSubmitHandler = () => {
    this.serializeToHiddenField();
  };

  private get inactiveList():HTMLElement|null {
    return this.inactiveContainerTarget.querySelector<HTMLElement>('ul.Box-list');
  }

  private initDrake() {
    // Sections drake — reorder entire sections by their section-handle
    this.sectionsDrake = dragula(
      [this.sectionsContainerTarget],
      {
        moves: (_el, _source, handle) => !!(handle as HTMLElement).closest('.section-handle'),
      },
    );

    // Attributes drake — move attribute rows between sections and the inactive panel
    const attrContainers = this.collectAttributeContainers();
    this.attributesDrake = dragula(
      attrContainers,
      {
        moves: (_el, _source, handle) => !!(handle as HTMLElement).closest('.attribute-handle'),
      },
    );

    // When an attribute row is dropped: show or hide the action menu column
    this.attributesDrake.on('drop', (el:Element, target:Element) => {
      const isInactive = target === this.inactiveList;
      if (isInactive) {
        el.querySelector<HTMLElement>('.js-row-actions')?.remove();
      } else if (!el.querySelector('.js-row-actions')) {
        el.appendChild(this.buildSimpleDeleteButton());
      }
    });

    // Autoscroll while dragging
    void window.OpenProject.getPluginContext().then((ctx) => {
      if (!this.element.isConnected) return;
      this.autoscroll = new ctx.classes.DomAutoscrollService(
        [document.getElementById('content-body')!],
        {
          margin: 25,
          maxSpeed: 10,
          scrollWhenOutside: true,
          autoScroll: () => !!(this.sectionsDrake?.dragging || this.attributesDrake?.dragging),
        },
      );
    });
  }

  private collectAttributeContainers():HTMLElement[] {
    const containers:HTMLElement[] = [];

    if (this.inactiveList) containers.push(this.inactiveList);

    this.sectionsContainerTarget
      .querySelectorAll<HTMLElement>('[data-group-type="attribute"]')
      .forEach((sectionEl) => {
        const ul = sectionEl.querySelector<HTMLElement>('ul.Box-list');
        if (ul) containers.push(ul);
      });

    return containers;
  }

  private setupFormSubmit() {
    const form = this.element.closest<HTMLFormElement>('form');
    form?.addEventListener('submit', this.formSubmitHandler);
  }

  private serializeToHiddenField() {
    const form = this.element.closest<HTMLFormElement>('form');
    if (!form) return;

    const hiddenField = form.querySelector<HTMLInputElement>('.admin-type-form--hidden-field');
    if (!hiddenField) return;

    const groups = this.readGroupsFromDOM();
    hiddenField.value = groups.length === 0
      ? JSON.stringify([{ type: 'attribute', key: EMPTY_GROUP_KEY, name: 'empty', attributes: [] }])
      : JSON.stringify(groups);
  }

  private readGroupsFromDOM():TypeGroup[] {
    const groups:TypeGroup[] = [];

    this.sectionsContainerTarget
      .querySelectorAll<HTMLElement>(':scope > [data-group-type]')
      .forEach((sectionEl) => {
        const type = sectionEl.dataset.groupType as 'attribute'|'query';
        const key = sectionEl.dataset.groupKey || null;
        const name = sectionEl.dataset.groupName || '';

        if (type === 'query') {
          groups.push({ type, key, name, attributes: null, query: sectionEl.dataset.groupQuery ?? null });
        } else {
          const attributes:TypeFormAttribute[] = [];
          sectionEl.querySelectorAll<HTMLElement>('li[data-attr-key]').forEach((attrEl) => {
            attributes.push({
              key: attrEl.dataset.attrKey!,
              translation: attrEl.dataset.attrTranslation!,
              is_cf: attrEl.dataset.attrIsCf === 'true',
            });
          });
          groups.push({ type, key, name, attributes });
        }
      });

    return groups;
  }

  private findSection(event:Event):HTMLElement|null {
    return (event.currentTarget as HTMLElement).closest<HTMLElement>('[data-group-type]');
  }

  private findRow(event:Event):HTMLElement|null {
    return (event.currentTarget as HTMLElement).closest<HTMLElement>('li[data-attr-key]');
  }

  private previousAttrRow(row:HTMLElement):HTMLElement|null {
    let prev = row.previousElementSibling as HTMLElement|null;
    while (prev && !prev.dataset.attrKey) {
      prev = prev.previousElementSibling as HTMLElement|null;
    }
    return prev;
  }

  private nextAttrRow(row:HTMLElement):HTMLElement|null {
    let next = row.nextElementSibling as HTMLElement|null;
    while (next && !next.dataset.attrKey) {
      next = next.nextElementSibling as HTMLElement|null;
    }
    return next;
  }

  private openRename(section:HTMLElement) {
    const nameDisplay = section.querySelector<HTMLElement>('.section-name-display');
    const nameInput = section.querySelector<HTMLInputElement>('.section-name-input');
    if (!nameDisplay || !nameInput) return;

    nameDisplay.style.display = 'none';
    nameInput.style.display = '';
    nameInput.focus();
    nameInput.select();
  }

  private buildSectionElement(type:'attribute'|'query', name:string):HTMLElement {
    const wrapper = document.createElement('div');
    wrapper.dataset.groupType = type;
    wrapper.dataset.groupKey = '';
    wrapper.dataset.groupName = name;
    if (type === 'query') {
      wrapper.dataset.groupQuery = this.noFilterQueryValue;
    }

    const box = document.createElement('div');
    box.className = 'Box mt-3 position-relative';
    wrapper.appendChild(box);

    // Box header
    const header = document.createElement('div');
    header.className = 'Box-header d-flex flex-items-center flex-justify-between';
    box.appendChild(header);

    // Left: drag handle + editable name
    const nameArea = document.createElement('div');
    nameArea.className = 'd-flex flex-items-center flex-1';
    nameArea.innerHTML = this.dragHandleSVG('section-handle');
    header.appendChild(nameArea);

    const nameSpan = document.createElement('span');
    nameSpan.className = 'section-name-display flex-1';
    nameSpan.style.cursor = 'pointer';
    nameSpan.textContent = name || I18n.t('js.admin.type_form.new_group');
    nameSpan.dataset.action = 'click->admin--type-form-configuration#startRenameSection';
    nameArea.appendChild(nameSpan);

    const nameInput = document.createElement('input');
    nameInput.type = 'text';
    nameInput.className = 'section-name-input';
    nameInput.value = name;
    nameInput.style.display = 'none';
    nameInput.dataset.action = [
      'blur->admin--type-form-configuration#saveRenameSection',
      'keydown.enter->admin--type-form-configuration#saveRenameSection',
      'keydown.escape->admin--type-form-configuration#cancelRenameSection',
    ].join(' ');
    nameArea.appendChild(nameInput);

    // Right: delete button
    const deleteBtn = document.createElement('button');
    deleteBtn.type = 'button';
    deleteBtn.className = 'Button Button--invisible Button--small';
    deleteBtn.setAttribute('aria-label', I18n.t('js.admin.type_form.delete_group'));
    deleteBtn.dataset.action = 'click->admin--type-form-configuration#deleteSection';
    deleteBtn.innerHTML = this.xIconSVG();
    header.appendChild(deleteBtn);

    // Rows container
    const ul = document.createElement('ul');
    ul.className = 'Box-list';
    box.appendChild(ul);

    if (type === 'query') {
      const queryRow = document.createElement('li');
      queryRow.className = 'Box-row d-flex flex-items-center flex-justify-between px-3 py-2';
      queryRow.innerHTML = `
        <span class="color-fg-subtle">${this.escapeHtml(I18n.t('js.admin.type_form.edit_query'))}</span>
        <button type="button"
                class="Button Button--invisible Button--small"
                data-action="click->admin--type-form-configuration#editQuery"
                aria-label="${this.escapeHtml(I18n.t('js.admin.type_form.edit_query'))}">
          ${this.pencilIconSVG()}
        </button>`;
      ul.appendChild(queryRow);
    }

    return wrapper;
  }

  private buildSimpleDeleteButton():HTMLElement {
    const col = document.createElement('div');
    col.className = 'js-row-actions';

    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'Button Button--invisible Button--small';
    btn.setAttribute('aria-label', I18n.t('js.admin.type_form.remove_attribute'));
    btn.dataset.action = 'click->admin--type-form-configuration#deleteRow';
    btn.innerHTML = this.xIconSVG();
    col.appendChild(btn);

    return col;
  }

  private dragHandleSVG(cssClass:string):string {
    return `<span class="DragHandle ${this.escapeHtml(cssClass)}" aria-label="${this.escapeHtml(I18n.t('js.admin.type_form.drag_to_reorder'))}">
      <svg aria-hidden="true" focusable="false" viewBox="0 0 16 16" width="16" height="16" fill="currentColor">
        <path d="M10 13a1 1 0 1 1 0-2 1 1 0 0 1 0 2Zm0-4a1 1 0 1 1 0-2 1 1 0 0 1 0 2Zm-4 4a1 1 0 1 1 0-2 1 1 0 0 1 0 2Zm5-9a1 1 0 1 1-2 0 1 1 0 0 1 2 0ZM7 8a1 1 0 1 1-2 0 1 1 0 0 1 2 0ZM6 5a1 1 0 1 1 0-2 1 1 0 0 1 0 2Z"/>
      </svg>
    </span>`;
  }

  private xIconSVG():string {
    return `<svg aria-hidden="true" focusable="false" class="octicon octicon-x" viewBox="0 0 16 16" width="16" height="16" fill="currentColor">
      <path d="M3.72 3.72a.75.75 0 0 1 1.06 0L8 6.94l3.22-3.22a.749.749 0 0 1 1.275.326.749.749 0 0 1-.215.734L9.06 8l3.22 3.22a.749.749 0 0 1-.326 1.275.749.749 0 0 1-.734-.215L8 9.06l-3.22 3.22a.751.751 0 0 1-1.042-.018.751.751 0 0 1-.018-1.042L6.94 8 3.72 4.78a.75.75 0 0 1 0-1.06Z"/>
    </svg>`;
  }

  private pencilIconSVG():string {
    return `<svg aria-hidden="true" focusable="false" class="octicon octicon-pencil" viewBox="0 0 16 16" width="16" height="16" fill="currentColor">
      <path d="M11.013 1.427a1.75 1.75 0 0 1 2.474 0l1.086 1.086a1.75 1.75 0 0 1 0 2.474l-8.61 8.61c-.21.21-.47.364-.756.445l-3.251.93a.75.75 0 0 1-.927-.928l.929-3.25c.081-.286.235-.547.445-.758l8.61-8.61Zm.176 4.823L9.75 4.81l-6.286 6.287a.253.253 0 0 0-.064.108l-.558 1.953 1.953-.558a.253.253 0 0 0 .108-.064Zm1.238-3.763a.25.25 0 0 0-.354 0L10.811 3.75l1.439 1.44 1.263-1.263a.25.25 0 0 0 0-.354Z"/>
    </svg>`;
  }

  private escapeHtml(str:string):string {
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }
}

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
import * as Turbo from '@hotwired/turbo';
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
    newSectionUrl: String,
  };

  declare readonly noFilterQueryValue:string;
  declare readonly eeAvailableValue:boolean;
  declare readonly newSectionUrlValue:string;

  private sectionsDrake:Drake|null = null;
  private attributesDrake:Drake|null = null;
  private autoscroll:DomAutoscrollService|null = null;
  private saveAbortController:AbortController|null = null;

  connect() {
    this.initDrake();
  }

  disconnect() {
    this.sectionsDrake?.destroy();
    this.attributesDrake?.destroy();
    this.autoscroll?.destroy();
    this.saveAbortController?.abort();
    this.sectionsDrake = null;
    this.attributesDrake = null;
    this.autoscroll = null;
    this.saveAbortController = null;
  }

  // ---- Subheader actions ----

  addAttributeSection(event:Event) {
    event.preventDefault();
    void this.postNewSection('attribute');
  }

  addQuerySection(event:Event) {
    event.preventDefault();
    void this.postNewSection('query');
  }

  confirmReset(event:Event) {
    event.preventDefault();
    const form = this.element.closest<HTMLFormElement>('form');
    if (!form) return;
    const hiddenField = form.querySelector<HTMLInputElement>('.admin-type-form--hidden-field');
    if (hiddenField) hiddenField.value = JSON.stringify([]);
    form.requestSubmit();
  }

  // ---- Filter ----

  filterInactives(event:Event) {
    const input = event.currentTarget as HTMLInputElement;
    const query = input.value.trim().toLowerCase();
    const inactiveUl = this.inactiveContainerTarget.querySelector<HTMLElement>('ul.Box-list');
    if (!inactiveUl) return;

    inactiveUl.querySelectorAll<HTMLElement>('li[data-attr-key]').forEach((row) => {
      const match = !query || (row.dataset.attrTranslation ?? '').toLowerCase().includes(query);
      row.style.display = match ? '' : 'none';
    });
  }

  // ---- Section rename ----

  startRenameSection(event:Event) {
    event.preventDefault();
    const section = this.findSection(event);
    if (section) this.openRename(section);
  }

  saveRenameSection(event:Event) {
    event.preventDefault();
    event.stopPropagation();

    const section = this.findSection(event);
    if (!section) return;

    const input = section.querySelector<HTMLInputElement>('input[name="section_name"]');
    if (!input) return;

    const newName = input.value.trim();
    if (!newName) return;

    section.dataset.groupName = newName;
    void this.autoSave();
  }

  cancelRenameSection(event:Event) {
    event.preventDefault();
    event.stopPropagation();

    const section = this.findSection(event);
    if (!section) return;

    const cancelUrl = section.dataset.cancelRenameUrl;
    if (cancelUrl) {
      void this.postCancelRename(cancelUrl);
    } else {
      // New unsaved section — remove it from the DOM
      section.remove();
    }
  }

  // ---- Section moves ----

  moveSectionTop(event:Event) {
    event.preventDefault();
    const section = this.findSection(event);
    if (!section?.parentElement) return;
    section.parentElement.prepend(section);
    void this.autoSave();
  }

  moveSectionUp(event:Event) {
    event.preventDefault();
    const section = this.findSection(event);
    if (!section?.previousElementSibling) return;
    section.parentElement!.insertBefore(section, section.previousElementSibling);
    void this.autoSave();
  }

  moveSectionDown(event:Event) {
    event.preventDefault();
    const section = this.findSection(event);
    if (!section?.nextElementSibling) return;
    section.parentElement!.insertBefore(section.nextElementSibling, section);
    void this.autoSave();
  }

  moveSectionBottom(event:Event) {
    event.preventDefault();
    const section = this.findSection(event);
    if (!section?.parentElement) return;
    section.parentElement.append(section);
    void this.autoSave();
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

    section.remove();
    void this.autoSave();
  }

  // ---- Row moves ----

  moveRowTop(event:Event) {
    event.preventDefault();
    const row = this.findRow(event);
    if (!row?.parentElement) return;
    const firstAttrRow = row.parentElement.querySelector<HTMLElement>('li[data-attr-key]');
    if (firstAttrRow && firstAttrRow !== row) row.parentElement.insertBefore(row, firstAttrRow);
    void this.autoSave();
  }

  moveRowUp(event:Event) {
    event.preventDefault();
    const row = this.findRow(event);
    if (!row) return;
    const prev = this.previousAttrRow(row);
    if (prev) row.parentElement!.insertBefore(row, prev);
    void this.autoSave();
  }

  moveRowDown(event:Event) {
    event.preventDefault();
    const row = this.findRow(event);
    if (!row) return;
    const next = this.nextAttrRow(row);
    if (next) row.parentElement!.insertBefore(next, row);
    void this.autoSave();
  }

  moveRowBottom(event:Event) {
    event.preventDefault();
    const row = this.findRow(event);
    if (!row?.parentElement) return;
    row.parentElement.appendChild(row);
    void this.autoSave();
  }

  // ---- Row delete ----

  deleteRow(event:Event) {
    event.preventDefault();
    const row = this.findRow(event);
    if (!row) return;

    row.querySelector<HTMLElement>('.js-row-actions')?.remove();

    const inactiveUl = this.inactiveContainerTarget.querySelector<HTMLElement>('ul.Box-list');
    if (inactiveUl) inactiveUl.appendChild(row);

    void this.autoSave();
  }

  // ---- Edit query ----

  editQuery(event:Event) {
    event.preventDefault();
    const section = this.findSection(event);
    if (section) this.openQueryEditor(section);
  }

  // ---- Private ----

  private async postCancelRename(cancelUrl:string):Promise<void> {
    const csrfToken = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? '';
    try {
      const response = await fetch(cancelUrl, {
        method: 'POST',
        headers: { Accept: 'text/vnd.turbo-stream.html', 'X-CSRF-Token': csrfToken },
      });
      if (response.ok) {
        Turbo.renderStreamMessage(await response.text());
        await new Promise<void>(r => requestAnimationFrame(() => r()));
        this.initSectionsDrake();
        this.initAttributesDrake();
      }
    } catch (err) {
      if (err instanceof Error && err.name !== 'AbortError') {
        console.error('Cancel rename failed:', err);
      }
    }
  }

  private async postNewSection(groupType:'attribute'|'query'):Promise<void> {
    const csrfToken = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? '';
    const response = await fetch(`${this.newSectionUrlValue}?group_type=${groupType}`, {
      method: 'POST',
      headers: { Accept: 'text/vnd.turbo-stream.html', 'X-CSRF-Token': csrfToken },
    });

    if (!response.ok) return;

    Turbo.renderStreamMessage(await response.text());
    await new Promise<void>(r => requestAnimationFrame(() => r()));

    // The new section is prepended — register its attribute list with Dragula
    // and open its rename input or query editor
    const newSection = this.sectionsContainerTarget.firstElementChild as HTMLElement|null;
    if (!newSection?.dataset.groupType) return;

    if (newSection.dataset.groupType === 'attribute' && this.attributesDrake) {
      const ul = newSection.querySelector<HTMLElement>('ul.Box-list');
      if (ul && !this.attributesDrake.containers.includes(ul)) {
        this.attributesDrake.containers.push(ul);
      }
    }

    if (newSection.dataset.editMode === 'true') {
      if (newSection.dataset.openQueryEditor === 'true') {
        this.openQueryEditor(newSection);
      } else {
        this.openRename(newSection);
      }
    }
  }

  // Serializes the current DOM, POSTs to the server, and applies the Turbo Stream
  // response. The server re-renders all sections with correct first?/last? flags
  // so action menus are always up-to-date. Cancels any in-flight save so rapid
  // actions always persist the latest state.
  private async autoSave():Promise<void> {
    this.saveAbortController?.abort();
    this.saveAbortController = new AbortController();
    this.serializeToHiddenField();

    const form = this.element.closest<HTMLFormElement>('form');
    if (!form) return;

    const csrfToken = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? '';
    try {
      const response = await fetch(form.action, {
        method: 'POST',
        headers: { Accept: 'text/vnd.turbo-stream.html', 'X-CSRF-Token': csrfToken },
        body: new FormData(form),
        signal: this.saveAbortController.signal,
      });

      if (response.ok) {
        Turbo.renderStreamMessage(await response.text());
        // Turbo defers stream actions to the next repaint (via requestAnimationFrame).
        // Wait one frame so the DOM update completes before we reinitialize Dragula.
        await new Promise<void>(r => requestAnimationFrame(() => r()));
        this.initSectionsDrake();
        this.initAttributesDrake();
      }
    } catch (err) {
      if (err instanceof Error && err.name !== 'AbortError') {
        console.error('Auto-save failed:', err);
      }
    }
  }

  private initDrake() {
    this.initSectionsDrake();
    this.initAttributesDrake();

    void window.OpenProject.getPluginContext().then((ctx) => {
      if (!this.element.isConnected) return;
      this.autoscroll = new ctx.classes.DomAutoscrollService(
        [document.getElementById('content-body')!],
        {
          margin: 25,
          maxSpeed: 10,
          scrollWhenOutside: true,
          autoScroll: () => Boolean((this.sectionsDrake?.dragging ?? false) || (this.attributesDrake?.dragging ?? false)),
        },
      );
    });
  }

  private initSectionsDrake() {
    this.sectionsDrake?.destroy();
    this.sectionsDrake = dragula(
      [this.sectionsContainerTarget],
      { moves: (_el, _source, handle) => !!(handle as HTMLElement).closest('.section-handle') },
    );
    this.sectionsDrake.on('drop', () => {
      void this.autoSave();
    });
  }

  // Initialises (or reinitialises) the attributes Dragula from the current DOM.
  // Called on connect and after every Turbo Stream replacement of the sections
  // container, because Turbo replaces <ul> nodes that Dragula held references to.
  private initAttributesDrake() {
    this.attributesDrake?.destroy();
    this.attributesDrake = dragula(
      this.collectAttributeContainers(),
      { moves: (_el, _source, handle) => !!(handle as HTMLElement).closest('.attribute-handle') },
    );

    this.attributesDrake.on('drop', (el:Element, target:Element) => {
      if (target === this.inactiveList) {
        el.querySelector<HTMLElement>('.js-row-actions')?.remove();
      }
      void this.autoSave();
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

  private openRename(section:HTMLElement) {
    const input = section.querySelector<HTMLInputElement>('input[name="section_name"]');
    if (!input) return;
    // Defer focus so the ActionMenu finishes closing first;
    // otherwise the menu's focus-return triggers an immediate blur on the input.
    setTimeout(() => { input.focus(); input.select(); }, 0);
  }

  private openQueryEditor(section:HTMLElement) {
    const currentQuery = JSON.parse(section.dataset.groupQuery ?? this.noFilterQueryValue) as unknown;
    const disabledTabs = {
      'display-settings': I18n.t('js.work_packages.table_configuration.embedded_tab_disabled'),
      timelines: I18n.t('js.work_packages.table_configuration.embedded_tab_disabled'),
    };

    void window.OpenProject.getPluginContext().then((ctx) => {
      if (!this.element.isConnected) return;
      ctx.services.externalRelationQueryConfiguration.show({
        currentQuery,
        callback: (queryProps:unknown) => {
          section.dataset.groupQuery = JSON.stringify(queryProps);
          void this.autoSave();
        },
        disabledTabs,
      });
    });
  }

  private get inactiveList():HTMLElement|null {
    return this.inactiveContainerTarget.querySelector<HTMLElement>('ul.Box-list');
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
        const name = sectionEl.dataset.groupName ?? '';

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
    while (prev && !prev.dataset.attrKey) prev = prev.previousElementSibling as HTMLElement|null;
    return prev;
  }

  private nextAttrRow(row:HTMLElement):HTMLElement|null {
    let next = row.nextElementSibling as HTMLElement|null;
    while (next && !next.dataset.attrKey) next = next.nextElementSibling as HTMLElement|null;
    return next;
  }
}

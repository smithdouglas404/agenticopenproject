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
import { FetchRequest } from '@rails/request.js';

export default class TypeFormConfigurationController extends Controller {
  static targets = ['groupsContainer', 'inactiveContainer'];

  declare readonly groupsContainerTarget:HTMLElement;
  declare readonly inactiveContainerTarget:HTMLElement;

  static values = {
    addGroupUrl: String,
    noFilterQuery: String,
    groupsUrl: String,
    updateUrl: String,
  };

  declare readonly addGroupUrlValue:string;
  declare readonly noFilterQueryValue:string;
  declare readonly groupsUrlValue:string;
  declare readonly updateUrlValue:string;

  addAttributeGroup(event:Event) {
    event.preventDefault();
    void this.postNewGroup('attribute');
  }

  addQueryGroup(event:Event) {
    event.preventDefault();

    this.openQueryEditor(this.noFilterQueryValue, (queryProps:unknown) => {
      void this.postNewGroup('query', queryProps);
    });
  }

  confirmReset(event:Event) {
    event.preventDefault();
    void this.resetToDefaults();
  }

  filterInactives(event:Event) {
    const input = event.currentTarget as HTMLInputElement;
    const query = input.value.trim().toLowerCase();
    const inactiveList = this.inactiveContainerTarget.querySelector<HTMLElement>(
      '[data-test-selector="type-form-configuration-inactive-list"]',
    );
    if (!inactiveList) return;

    inactiveList.querySelectorAll<HTMLElement>('li[data-attr-key]').forEach((row) => {
      const match = !query || (row.dataset.attrTranslation ?? '').toLowerCase().includes(query);
      row.style.display = match ? '' : 'none';
    });
  }

  editQuery(event:Event) {
    event.preventDefault();

    const group = (event.currentTarget as HTMLElement).closest<HTMLElement>('[data-group-key]');
    if (!group) return;

    this.openQueryEditor(group.dataset.groupQuery ?? this.noFilterQueryValue, (queryProps:unknown) => {
      const key = group.dataset.groupKey;
      if (!key) return;

      void this.postQueryUpdate(key, queryProps).then((success) => {
        if (success) {
          group.dataset.groupQuery = JSON.stringify(queryProps);
        }
      });
    });
  }

  private async postNewGroup(groupType:'attribute'|'query', queryProps?:unknown):Promise<void> {
    const request = new FetchRequest('post', this.addGroupUrlValue, {
      body: {
        group_type: groupType,
        query: queryProps ? JSON.stringify(queryProps) : undefined,
      },
      responseKind: 'turbo-stream',
    });

    const response = await request.perform();
    if (!response.ok) return;

    await new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
    this.focusGroupInput();
  }

  private async postQueryUpdate(groupKey:string, queryProps:unknown):Promise<boolean> {
    const request = new FetchRequest('patch', `${this.groupsUrlValue}/${encodeURIComponent(groupKey)}/update_query`, {
      body: {
        query: JSON.stringify(queryProps),
      },
      responseKind: 'turbo-stream',
    });

    const response = await request.perform();
    return response.ok;
  }

  private focusGroupInput() {
    const input = this.groupsContainerTarget
      .querySelector<HTMLInputElement>('[data-edit-mode="true"] input[name="group[name]"]');

    if (!input) return;

    input.focus();
    input.setSelectionRange(input.value.length, input.value.length);
  }

  private async resetToDefaults():Promise<void> {
    const body = new FormData();
    body.append('type[attribute_groups]', '[]');

    const request = new FetchRequest('patch', this.updateUrlValue, {
      body,
      responseKind: 'turbo-stream',
    });

    await request.perform();
  }

  private openQueryEditor(queryJson:string, callback:(queryProps:unknown) => void) {
    const currentQuery = JSON.parse(queryJson) as unknown;
    const disabledTabs = {
      'display-settings': I18n.t('js.work_packages.table_configuration.embedded_tab_disabled'),
      timelines: I18n.t('js.work_packages.table_configuration.embedded_tab_disabled'),
    };

    void window.OpenProject.getPluginContext().then((ctx) => {
      if (!this.element.isConnected) return;

      ctx.services.externalRelationQueryConfiguration.show({
        currentQuery,
        callback,
        disabledTabs,
      });
    });
  }
}

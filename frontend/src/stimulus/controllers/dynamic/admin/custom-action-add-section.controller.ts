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
 *
 */

import { Controller } from '@hotwired/stimulus';
import { renderStreamMessage } from '@hotwired/turbo';

const sectionsChangedEvent = 'custom-action:sections-changed';

export default class extends Controller {
  static targets = ['select'];

  static values = {
    url: String,
    containerId: String,
    id: { type: String, default: '' },
  };

  declare readonly selectTarget:HTMLSelectElement;
  declare readonly urlValue:string;
  declare readonly containerIdValue:string;
  declare readonly idValue:string;

  private onSectionsChangedBound = ():void => this.refreshDisabledOptions();

  connect():void {
    window.addEventListener(sectionsChangedEvent, this.onSectionsChangedBound);
    this.refreshDisabledOptions();
  }

  disconnect():void {
    window.removeEventListener(sectionsChangedEvent, this.onSectionsChangedBound);
  }

  async add():Promise<void> {
    const key = this.selectTarget.value;
    if (!key) {
      return;
    }

    const params = new URLSearchParams();
    params.set('key', key);
    if (this.idValue) {
      params.set('id', this.idValue);
    }

    const url = `${this.urlValue}?${params.toString()}`;

    const response = await fetch(url, {
      headers: {
        Accept: 'text/vnd.turbo-stream.html',
      },
    });

    const html = await response.text();
    renderStreamMessage(html);

    this.selectTarget.value = '';
    this.scheduleRefresh();
  }

  private getActiveKeysFromContainer():string[] {
    const container = document.getElementById(this.containerIdValue);
    if (!container) {
      return [];
    }

    return Array.from(container.querySelectorAll<HTMLElement>('[data-name]'))
      .map((el) => el.dataset.name)
      .filter((name):name is string => Boolean(name));
  }

  private refreshDisabledOptions():void {
    const activeKeysSet = new Set(this.getActiveKeysFromContainer());

    Array.from(this.selectTarget.options).forEach((option) => {
      if (!option.value) {
        return;
      }

      option.disabled = activeKeysSet.has(option.value);
    });
  }

  private scheduleRefresh():void {
    requestAnimationFrame(() => {
      this.refreshDisabledOptions();
      window.dispatchEvent(new CustomEvent(sectionsChangedEvent));
    });
  }
}

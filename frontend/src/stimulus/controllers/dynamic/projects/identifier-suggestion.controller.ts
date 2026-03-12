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

import {Controller} from '@hotwired/stimulus';
import {debounce, DebouncedFunc} from 'lodash';

const ALLOWED_CHARS:Record<string, RegExp> = {
  semantic: /[^A-Z0-9_]/g,
  legacy: /[^a-z0-9\-_]/g,
};

export default class extends Controller {
  static values = {
    url: String,
    debounce: {type: Number, default: 300},
    mode: {type: String, default: 'legacy'},
  };

  declare urlValue:string;
  declare debounceValue:number;
  declare modeValue:string;

  private nameInput:HTMLInputElement | null = null;
  private identifierInput:HTMLInputElement | null = null;
  private debouncedSuggest:DebouncedFunc<(name:string) => Promise<void>> | null = null;
  private handleBlur:((event:Event) => void) | null = null;
  private handleInput:((event:Event) => void) | null = null;

  connect():void {
    this.nameInput = this.element.querySelector<HTMLInputElement>('[name="project[name]"]');
    this.identifierInput = this.element.querySelector<HTMLInputElement>('[name="project[identifier]"]');

    if (!this.nameInput || !this.identifierInput) return;

    this.handleInput = () => this.filterInput();
    this.identifierInput.addEventListener('input', this.handleInput);

    if (this.urlValue) {
      if (!this.identifierInput.value) {
        this.identifierInput.placeholder = I18n.t('js.projects.identifier_suggestion.set_name_first');
        this.identifierInput.readOnly = true;
      }

      this.debouncedSuggest = debounce(
        (name:string) => this.fetchSuggestion(name),
        this.debounceValue,
      );

      this.handleBlur = () => {
        const name = this.nameInput!.value.trim();
        if (name) void this.debouncedSuggest!(name);
      };

      this.nameInput.addEventListener('blur', this.handleBlur);
    }
  }

  disconnect():void {
    this.debouncedSuggest?.cancel();
    if (this.nameInput && this.handleBlur) {
      this.nameInput.removeEventListener('blur', this.handleBlur);
    }
    if (this.identifierInput && this.handleInput) {
      this.identifierInput.removeEventListener('input', this.handleInput);
    }
  }

  private filterInput():void {
    if (!this.identifierInput) return;

    const pattern = ALLOWED_CHARS[this.modeValue] ?? ALLOWED_CHARS.legacy;
    const current = this.identifierInput.value;
    const filtered = current.replace(pattern, '');

    if (filtered !== current) {
      const pos = this.identifierInput.selectionStart ?? filtered.length;
      this.identifierInput.value = filtered;
      const newPos = Math.min(pos, filtered.length);
      this.identifierInput.setSelectionRange(newPos, newPos);
    }
  }

  private async fetchSuggestion(name:string):Promise<void> {
    if (!this.urlValue) return;

    if (this.identifierInput) {
      this.identifierInput.readOnly = true;
      this.identifierInput.placeholder = I18n.t('js.projects.identifier_suggestion.loading');
    }

    try {
      const url = `${this.urlValue}?name=${encodeURIComponent(name)}`;
      const response = await fetch(url, {headers: {Accept: 'application/json'}});

      if (!response.ok) return;

      const data = await response.json() as { identifier:string };
      if (this.identifierInput) {
        this.identifierInput.value = data.identifier;
      }
    } finally {
      if (this.identifierInput) {
        this.identifierInput.readOnly = false;
        this.identifierInput.placeholder = '';
      }
    }
  }
}

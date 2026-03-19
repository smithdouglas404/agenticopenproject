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

const SAVED_STATE_KEY = 'workflow-saved-state';

interface SavedState {
  formKey:string;
  checkboxes:Record<string, boolean>;
}

export default class WorkflowCheckboxStateController extends Controller<HTMLFormElement> {
  connect() {
    const frame = this.element.closest<HTMLElement>('turbo-frame');
    frame?.addEventListener('turbo:before-frame-render', this.onBeforeFrameRender);

    const saved = this.loadSavedState();
    if (saved?.formKey === this.formKey) {
      this.applyState(saved.checkboxes);
    }

    this.element.addEventListener('submit', this.onFormSubmit);
  }

  disconnect() {
    this.element.closest('turbo-frame')?.removeEventListener('turbo:before-frame-render', this.onBeforeFrameRender);
    this.element.removeEventListener('submit', this.onFormSubmit);
  }

  private onBeforeFrameRender = () => {
    const checkboxes:Record<string, boolean> = {};
    this.element.querySelectorAll<HTMLInputElement>('input[type="checkbox"]').forEach((cb) => {
      checkboxes[`${cb.dataset.oldStatus}:${cb.dataset.newStatus}:${cb.value}`] = cb.checked;
    });

    const state:SavedState = { formKey: this.formKey, checkboxes };
    sessionStorage.setItem(SAVED_STATE_KEY, JSON.stringify(state));
  };

  private onFormSubmit = () => {
    sessionStorage.removeItem(SAVED_STATE_KEY);
  };

  private get formKey():string {
    return `${this.formValue('type_id')}-${this.formValue('role_id')}`;
  }

  private formValue(name:string):string {
    return this.element.querySelector<HTMLInputElement>(`input[name="${name}"]`)!.value;
  }

  private loadSavedState():SavedState | null {
    const raw = sessionStorage.getItem(SAVED_STATE_KEY);
    sessionStorage.removeItem(SAVED_STATE_KEY);
    if (!raw) return null;

    return JSON.parse(raw) as SavedState;
  }

  private applyState(checkboxes:Record<string, boolean>):void {
    this.element.querySelectorAll<HTMLInputElement>('input[type="checkbox"]').forEach((cb) => {
      const key = `${cb.dataset.oldStatus}:${cb.dataset.newStatus}:${cb.value}`;
      if (key in checkboxes) cb.checked = checkboxes[key];
    });
  }
}

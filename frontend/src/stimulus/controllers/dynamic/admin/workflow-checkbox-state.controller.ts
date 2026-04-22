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
import { TurboRequestsService } from 'core-app/core/turbo/turbo-requests.service';

const SAVED_STATE_KEY = 'workflow-saved-state';

interface SavedState {
  formKey:string;
  checkboxes:Record<string, boolean>;
}

/**
 * Handles two things:
 * 1) Saving and restoring checked state of each checkbox when updating statuses,
 * since this refreshes the turbo frame and the checked state is not directly saved
 * to the DB
 *
 * 2) Marking the checkbox matrix as dirty when changes are made but not saved, and
 * passing this info along when roles/tabs are changed to trigger a confirmation
 * dialog when necessary:
 *   - Roles are handled by setting an attribute on each ActionMenu item when dirty.
 *   This param decides if the controller responds with a confirmation dialog,
 *   or simply redirects
 *   - Tabs are handled by listening for clicks on the tab headers, and directly
 * calling the confirmation dialog from here when dirty
 */
export default class WorkflowCheckboxStateController extends Controller<HTMLFormElement> {
  private initialCheckboxState:Record<string, boolean> = {};
  private turboRequests:TurboRequestsService;
  private hasStatusChanges = false;

  connect() {
    void window.OpenProject.getPluginContext().then((context) => {
      this.turboRequests = context.services.turboRequests;
    });

    const frame = this.element.closest<HTMLElement>('turbo-frame');
    frame?.addEventListener('turbo:before-frame-render', this.onBeforeFrameRender);

    const saved = this.loadSavedState();
    if (saved?.formKey === this.formKey) {
      this.applyState(saved.checkboxes);
    }

    this.element.addEventListener('submit', this.onFormSubmit);

    this.hasStatusChanges = this.element.dataset.hasStatusChanges === 'true';
    this.initialCheckboxState = this.captureState();
    this.element.addEventListener('change', this.onCheckboxChange);

    document.addEventListener('click', this.onTabLinkClick, true);

    if (this.hasStatusChanges) {
      this.updateRoleDirtyParams(true);
      window.OpenProject.pageState = 'edited';
    }
  }

  disconnect() {
    this.element.closest('turbo-frame')?.removeEventListener('turbo:before-frame-render', this.onBeforeFrameRender);
    this.element.removeEventListener('submit', this.onFormSubmit);
    this.element.removeEventListener('change', this.onCheckboxChange);
    document.removeEventListener('click', this.onTabLinkClick, true);
  }

  private onBeforeFrameRender = () => {
    const state:SavedState = { formKey: this.formKey, checkboxes: this.captureState() };
    sessionStorage.setItem(SAVED_STATE_KEY, JSON.stringify(state));
  };

  private onFormSubmit = () => {
    sessionStorage.removeItem(SAVED_STATE_KEY);
    this.element.dataset.dirty = 'false';
  };

  private onCheckboxChange = () => {
    const current = this.captureState();
    const checkboxesDirty = Object.keys(current).some((key) => current[key] !== this.initialCheckboxState[key]);
    const dirty = this.hasStatusChanges || checkboxesDirty;
    this.element.dataset.dirty = dirty ? 'true' : 'false';
    this.updateRoleDirtyParams(dirty);
    window.OpenProject.pageState = dirty ? 'edited' : 'pristine';
  };

  private onTabLinkClick = (event:Event) => {
    const target = (event.target as HTMLElement).closest<HTMLAnchorElement>('[data-workflow-tab-link]');
    if (!target) return;
    if (target.dataset.workflowTabCurrent === 'true') return;
    if (this.element.dataset.dirty !== 'true' && !this.hasStatusChanges) return;

    event.preventDefault();
    event.stopImmediatePropagation();

    void this.turboRequests.request(target.dataset.confirmationUrl!, {
      method: 'POST',
      headers: { Accept: 'text/vnd.turbo-stream.html' },
    });
  };

  private updateRoleDirtyParams(dirty:boolean):void {
    const frame = this.element.closest('turbo-frame');
    frame?.querySelectorAll<HTMLFormElement>('[data-workflow-role-form]').forEach((form) => {
      const url = new URL(form.action);
      url.searchParams.set('dirty', dirty ? 'true' : 'false');
      form.action = url.toString();
    });
  }

  private captureState():Record<string, boolean> {
    const checkboxes:Record<string, boolean> = {};
    this.element.querySelectorAll<HTMLInputElement>('input[type="checkbox"]').forEach((cb) => {
      checkboxes[`${cb.dataset.oldStatus}:${cb.dataset.newStatus}:${cb.value}`] = cb.checked;
    });
    return checkboxes;
  }

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

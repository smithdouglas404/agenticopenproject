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
  static targets = [ 'confirmationDialog', 'ignoreButton', 'saveButton' ];
  declare readonly confirmationDialogTarget:HTMLDialogElement;
  declare readonly ignoreButtonTarget:HTMLButtonElement;
  declare readonly saveButtonTarget:HTMLButtonElement;

  static values = {
    hasStatusChanges: Boolean
  };

  declare hasStatusChangesValue:boolean;

  private initialCheckboxState:Record<string, boolean> = {};
  private confirmationTriggers:NodeListOf<HTMLElement>;

  connect() {
    const frame = this.element.closest<HTMLElement>('turbo-frame');
    frame?.addEventListener('turbo:before-frame-render', this.onBeforeFrameRender);

    const saved = this.loadSavedState();
    if (saved?.formKey === this.formKey) {
      this.applyState(saved.checkboxes);
    }

    this.element.addEventListener('submit', this.onFormSubmit);

    this.initialCheckboxState = this.captureState();
    this.element.addEventListener('change', this.onCheckboxChange);

    this.confirmationTriggers = document.querySelectorAll<HTMLElement>('[data-admin--workflow-checkbox-state-confirmation-trigger]');
    this.confirmationTriggers.forEach((watchedElement) => {
      const watchedTrigger = watchedElement.dataset['admin-WorkflowCheckboxStateConfirmationTrigger'] ?? '';
      watchedElement.addEventListener(watchedTrigger, this.confirmWithDialog, true);
    });

    if (this.hasStatusChangesValue) {
      window.OpenProject.pageState = 'edited';
    }
  }

  disconnect() {
    this.element.closest('turbo-frame')?.removeEventListener('turbo:before-frame-render', this.onBeforeFrameRender);
    this.element.removeEventListener('submit', this.onFormSubmit);

    this.confirmationTriggers.forEach((watchedElement) => {
      const watchedTrigger = watchedElement.dataset['admin-WorkflowCheckboxStateConfirmationTrigger'] ?? '';
      watchedElement.removeEventListener(watchedTrigger, this.confirmWithDialog, true);
    });
    this.element.removeEventListener('change', this.onCheckboxChange);
  }

  //
  // Save current state before rendering the matrix with new statuses.
  // Restores state on connect, after after new statuses rendered.
  //

  private onBeforeFrameRender = () => {
    const state:SavedState = { formKey: this.formKey, checkboxes: this.captureState() };
    sessionStorage.setItem(SAVED_STATE_KEY, JSON.stringify(state));
  };

  private onFormSubmit = () => {
    sessionStorage.removeItem(SAVED_STATE_KEY);
    this.element.dataset.dirty = 'false';
    this.hasStatusChangesValue = false;
    window.OpenProject.pageState = 'pristine';
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

  //
  // Hook "Unsaved changes" dialog to triggers to prevent data loss.
  // Asks for confirmation and proceed to requested event.
  //

  private confirmWithDialog = (event:Event) => {
    if (!this.isDirty) return;

    const target = event.target as HTMLElement;

    if (!target.dataset.confirmed) {
      event.preventDefault();
      event.stopImmediatePropagation();

      this.showDialog(target, event);
    }
    else {
      // Reset confirmation status for next time
      delete target.dataset.confirmed;
      // Let default behaviour behave…
    }
  };

  private showDialog = (target:HTMLElement, event:Event) => {
    const onIgnoreCallback = this.onIgnoreChanges(target, event);
    this.ignoreButtonTarget.addEventListener('click', onIgnoreCallback);

    const onSaveCallback = this.onSaveChanges(target, event);
    this.saveButtonTarget.addEventListener('click', onSaveCallback);

    this.confirmationDialogTarget.addEventListener('close', () => {
      this.ignoreButtonTarget.removeEventListener('click', onIgnoreCallback);
      this.saveButtonTarget.removeEventListener('click', onSaveCallback);
    });

    this.confirmationDialogTarget.showModal();
  };

  private onIgnoreChanges = (originalTarget:HTMLElement, originalEvent:Event) => {
    return () => {
      this.applyState(this.initialCheckboxState);
      this.element.dataset.dirty = 'false';
      window.OpenProject.pageState = 'pristine';

      this.closeAndProceed(originalTarget, originalEvent);
    };
  };

  private onSaveChanges = (originalTarget:HTMLElement, originalEvent:Event) => {
    return () => {
      this.element.requestSubmit();

      this.closeAndProceed(originalTarget, originalEvent);
    };
  };

  private closeAndProceed = (originalTarget:HTMLElement, originalEvent:Event) => {
    this.confirmationDialogTarget.close();
    originalTarget.dataset.confirmed = 'true';

    if (originalEvent.type === 'click') {
      // Dispatching a click event is not as effective as explicitly clicking
      originalTarget.click();
    }
    else {
      const forwardedEvent = new Event(originalEvent.type, { bubbles: true });
      originalTarget.dispatchEvent(forwardedEvent);
    }
  };

  //
  // Foundation for state management: save, apply and track dirtiness.
  //

  private get isDirty():boolean {
    return (this.element.dataset.dirty === 'true') || this.hasStatusChangesValue;
  }

  private onCheckboxChange = () => {
    const current = this.captureState();
    const dirty = Object.keys(current).some((key) => current[key] !== this.initialCheckboxState[key]);
    this.element.dataset.dirty = dirty ? 'true' : 'false';
    window.OpenProject.pageState = dirty ? 'edited' : 'pristine';
  };

  private captureState():Record<string, boolean> {
    const checkboxes:Record<string, boolean> = {};
    this.element.querySelectorAll<HTMLInputElement>('input[type="checkbox"]').forEach((cb) => {
      checkboxes[`${cb.dataset.oldStatus}:${cb.dataset.newStatus}:${cb.value}`] = cb.checked;
    });
    return checkboxes;
  }

  private applyState(checkboxes:Record<string, boolean>):void {
    this.element.querySelectorAll<HTMLInputElement>('input[type="checkbox"]').forEach((cb) => {
      const key = `${cb.dataset.oldStatus}:${cb.dataset.newStatus}:${cb.value}`;
      if (key in checkboxes) cb.checked = checkboxes[key];
    });
  }
}

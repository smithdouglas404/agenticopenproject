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

const PRISTINE_STATE_KEY = 'workflow-pristine-state';
const STATUS_STATE_KEY = 'workflow-status-state';

type CheckboxesState = Record<string, boolean>;

interface SavedState {
  formKey:string;
  checkboxes:CheckboxesState;
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
    hasStatusChanges: Boolean,
    hasCheckboxChanges: Boolean,
    isDirty: Boolean
  };

  declare hasStatusChangesValue:boolean;
  declare hasCheckboxChangesValue:boolean;
  declare isDirtyValue:boolean;

  private initialCheckboxState:CheckboxesState = {};
  private confirmationTriggers:NodeListOf<HTMLElement>;

  connect() {
    const frame = this.element.closest<HTMLElement>('turbo-frame');
    frame?.addEventListener('turbo:before-frame-render', this.onBeforeFrameRender);

    this.element.addEventListener('change', this.onCheckboxChange);
    this.element.addEventListener('submit', this.onFormSubmit);

    this.initialCheckboxState = this.popState(PRISTINE_STATE_KEY) ?? this.captureState();
    this.pushState(PRISTINE_STATE_KEY, this.initialCheckboxState);

    const statusCheckboxes = this.popState(STATUS_STATE_KEY);
    if (statusCheckboxes) {
      this.applyState(statusCheckboxes);
    }

    this.confirmationTriggers = document.querySelectorAll<HTMLElement>('[data-admin--workflow-checkbox-state-confirmation-trigger]');
    this.confirmationTriggers.forEach((watchedElement) => {
      const watchedTrigger = watchedElement.dataset['admin-WorkflowCheckboxStateConfirmationTrigger'] ?? '';
      watchedElement.addEventListener(watchedTrigger, this.confirmWithDialog, true);
    });
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
    if (this.hasCheckboxChangesValue) {
      this.pushState(STATUS_STATE_KEY, this.captureState());
    };
  };

  private onFormSubmit = () => {
    this.popState(STATUS_STATE_KEY);
    this.popState(PRISTINE_STATE_KEY);
    this.hasCheckboxChangesValue = false;
    this.hasStatusChangesValue = false;
  };

  private get formKey():string {
    return `${this.formValue('type_id')}-${this.formValue('role_id')}`;
  }

  private formValue(name:string):string {
    return this.element.querySelector<HTMLInputElement>(`input[name="${name}"]`)!.value;
  }

  private pushState(key:string, state:CheckboxesState) {
    const savedState:SavedState = { formKey: this.formKey, checkboxes: state };
    sessionStorage.setItem(key, JSON.stringify(savedState));
  }

  private popState(key:string):CheckboxesState | null {
    const raw = sessionStorage.getItem(key);
    sessionStorage.removeItem(key);
    if (!raw) return null;

    const savedState = JSON.parse(raw) as SavedState;
    if (savedState.formKey !== this.formKey) return null;

    return savedState.checkboxes;
  }

  //
  // Hook "Unsaved changes" dialog to triggers to prevent data loss.
  // Asks for confirmation and proceed to requested event.
  //

  private confirmWithDialog = (event:Event) => {
    if (!this.isDirtyValue) return;

    const target = event.target as HTMLElement;

    if (!target.dataset.confirmed) {
      event.preventDefault();
      event.stopImmediatePropagation();

      this.showDialog(target, event);
    }
    else {
      // Reset confirmation status for next time
      delete target.dataset.confirmed;
      // Reset dirtiness status for next time
      this.hasCheckboxChangesValue = false;
      this.hasStatusChangesValue = false;
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
      const turboFrame = this.element.closest('turbo-frame') as HTMLElement;
      const src = turboFrame.getAttribute('src') ?? '';
      const url = new URL(src);
      // Reload only with original params
      const params = new URLSearchParams();
      params.set('role_id', url.searchParams.get('role_id') ?? '');
      url.search = params.toString();
      turboFrame.setAttribute('src', url.toString());

      this.hasCheckboxChangesValue = false;
      this.hasStatusChangesValue = false;

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

    // Delay to allow the flash message from the form submission to appear.
    setTimeout(() => {
      if (originalEvent.type === 'click') {
        // Dispatching a click event is not as effective as explicitly clicking.
        originalTarget.click();
      }
      else {
        const forwardedEvent = new Event(originalEvent.type, { bubbles: true });
        originalTarget.dispatchEvent(forwardedEvent);
      }
    }, 1000);
  };

  //
  // Foundation for state management: save, apply and track dirtiness.
  //

  private hasCheckboxChangesValueChanged(hasChanges:boolean) {
    this.isDirtyValue = hasChanges || this.hasStatusChangesValue;
  }

  private hasStatusChangesValueChanged(hasChanges:boolean) {
    this.isDirtyValue = hasChanges || this.hasCheckboxChangesValue;
  }

  private isDirtyValueChanged(hasChanges:boolean) {
    window.OpenProject.pageState = hasChanges ? 'edited' : 'pristine';
  }

  private onCheckboxChange = () => {
    const current = this.captureState();
    const hasChanges = Object.keys(current).some((key) => current[key] !== this.initialCheckboxState[key]);

    this.hasCheckboxChangesValue = hasChanges;
  };

  private captureState():Record<string, boolean> {
    const checkboxes:Record<string, boolean> = {};
    this.element.querySelectorAll<HTMLInputElement>('input[type="checkbox"]').forEach((cb) => {
      checkboxes[`${cb.dataset.oldStatus}:${cb.dataset.newStatus}:${cb.value}`] = cb.checked;
    });
    return checkboxes;
  }

  private applyState(checkboxes:Record<string, boolean>, defaultValue?:boolean):void {
    this.element.querySelectorAll<HTMLInputElement>('input[type="checkbox"]').forEach((cb) => {
      const key = `${cb.dataset.oldStatus}:${cb.dataset.newStatus}:${cb.value}`;

      cb.checked = checkboxes[key] ?? defaultValue ?? true;
    });
  }
}

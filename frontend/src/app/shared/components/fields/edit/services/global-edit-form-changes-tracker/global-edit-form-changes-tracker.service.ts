import { Injectable, inject } from '@angular/core';
import { EditFormComponent } from 'core-app/shared/components/fields/edit/edit-form/edit-form.component';
import { I18nService } from 'core-app/core/i18n/i18n.service';

@Injectable({
  providedIn: 'root',
})
export class GlobalEditFormChangesTrackerService {
  private i18nService = inject(I18nService);

  private activeForms = new Map<EditFormComponent, boolean>();

  get thereAreFormsWithUnsavedChanges() {
    return Array.from(this.activeForms.keys()).some((form) => !form.change.inFlight && !form.change.isEmpty());
  }

  constructor() {
    window.OpenProject.editFormsContainUnsavedChanges = () => this.thereAreFormsWithUnsavedChanges;

    // Global beforeunload hook to show a data loss warn
    // when the user clicks on a link out of the Angular app
    window.addEventListener('beforeunload', (event) => {
      if (!window.OpenProject.pageWasSubmitted && this.thereAreFormsWithUnsavedChanges) {
        const message = this.i18nService.t<string>('js.work_packages.confirm_edit_cancel');

        event.preventDefault();
        event.returnValue = message;
      }
    });
  }

  public addToActiveForms(form:EditFormComponent) {
    this.activeForms.set(form, true);
  }

  public removeFromActiveForms(form:EditFormComponent) {
    this.activeForms.delete(form);
  }
}

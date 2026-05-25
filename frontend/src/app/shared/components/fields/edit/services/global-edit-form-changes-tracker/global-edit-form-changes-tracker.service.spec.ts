import { TestBed } from '@angular/core/testing';
import { EditFormComponent } from 'core-app/shared/components/fields/edit/edit-form/edit-form.component';
import { OpenProject } from 'core-app/core/setup/globals/openproject';
import { GlobalEditFormChangesTrackerService } from './global-edit-form-changes-tracker.service';

describe('GlobalEditFormChangesTrackerService', () => {
  let service:GlobalEditFormChangesTrackerService;
  let originalOpenProject:OpenProject;
  const createForm = (changed?:boolean, inFlight = false) => ({
    editing: false,
    change: {
      inFlight,
      isEmpty: () => !changed,
    },
  } as EditFormComponent);

  beforeEach(() => {
    originalOpenProject = window.OpenProject;
    window.OpenProject = new OpenProject();
    TestBed.configureTestingModule({});
    service = TestBed.inject(GlobalEditFormChangesTrackerService);
  });

  afterEach(() => {
    window.OpenProject = originalOpenProject;
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('should report no changes when empty', () => {
    expect(service.thereAreFormsWithUnsavedChanges).toBe(false);
  });

  it('should report no changes when one form has no changes', () => {
    const form = createForm();

    service.addToActiveForms(form);

    expect(service.thereAreFormsWithUnsavedChanges).toBe(false);
  });

  it('should report no changes when multiple forms have no changes', () => {
    const form = createForm();
    const form2 = createForm();
    const form3 = createForm();

    service.addToActiveForms(form);
    service.addToActiveForms(form2);
    service.addToActiveForms(form3);

    expect(service.thereAreFormsWithUnsavedChanges).toBe(false);
  });

  it('should report no changes when the only form with changes is removed', () => {
    const form = createForm(true);

    service.addToActiveForms(form);
    service.removeFromActiveForms(form);

    expect(service.thereAreFormsWithUnsavedChanges).toBe(false);
  });

  it('should report changes when one form has changes', () => {
    const form = createForm(true);

    service.addToActiveForms(form);

    expect(service.thereAreFormsWithUnsavedChanges).toBe(true);
  });

  it('should report no changes when one form is editing without changes', () => {
    const form = {
      ...createForm(),
      editing: true,
    } as EditFormComponent;

    service.addToActiveForms(form);

    expect(service.thereAreFormsWithUnsavedChanges).toBe(false);
  });

  it('should report no changes when the only changed form is being saved', () => {
    const form = createForm(true, true);

    service.addToActiveForms(form);

    expect(service.thereAreFormsWithUnsavedChanges).toBe(false);
  });

  it('should report changes when another form has unsaved changes while one is being saved', () => {
    const savingForm = createForm(true, true);
    const changedForm = createForm(true);

    service.addToActiveForms(savingForm);
    service.addToActiveForms(changedForm);

    expect(service.thereAreFormsWithUnsavedChanges).toBe(true);
  });

  it('should report forms with changes when multiple form have changes', () => {
    const form = createForm(true);
    const form2 = createForm(true);
    const form3 = createForm();

    service.addToActiveForms(form);
    service.addToActiveForms(form2);
    service.addToActiveForms(form3);

    expect(service.thereAreFormsWithUnsavedChanges).toBe(true);
  });

  it('should prevent beforeunload when a tracked form has changes', () => {
    const form = createForm(true);
    const event = new Event('beforeunload', { cancelable: true });

    service.addToActiveForms(form);
    window.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(true);
  });

  it('should not prevent beforeunload when the page was submitted', () => {
    const form = createForm(true);
    const event = new Event('beforeunload', { cancelable: true });

    window.OpenProject.pageState = 'submitted';
    service.addToActiveForms(form);
    window.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(false);
  });

  it('registers an OpenProject callback for edit form changes', () => {
    const form = createForm(true);

    service.addToActiveForms(form);

    expect(window.OpenProject.editFormsContainUnsavedChanges()).toBe(true);
  });
});

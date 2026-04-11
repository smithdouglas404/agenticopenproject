//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import { ConfirmDialogService } from 'core-app/shared/components/modals/confirm-dialog/confirm-dialog.service';

export function confirm(
  message:string,
  formElement:HTMLFormElement,
  submitter?:HTMLButtonElement|HTMLInputElement
) {
  const dangerHighlighting = submitter
    ? getFormMethod(submitter, formElement) === 'delete'
    : true;

  return window
    .OpenProject
    .getPluginContext()
    .then((pluginContext) => pluginContext.injector.get(ConfirmDialogService))
    .then((service) => service.confirm({
      text: { title: I18n.t('js.modals.form_submit.title'), text: message },
      dangerHighlighting
    }))
    .then(
      () => { return true; },
      () => { return false; }
    );
}

/**
 * Gets the HTTP method for a form submission, checking the submitter's formmethod attribute first,
 * then falling back to the form's method attribute, and finally defaulting to 'get'.
 *
 * @param submitter - The button or input[type="submit"] element that triggered the submission
 * @param formElement - The form element being submitted
 * @returns The HTTP method to use for the form submission
 */
function getFormMethod(submitter:HTMLButtonElement | HTMLInputElement, formElement:HTMLFormElement):string {
  return submitter.getAttribute('formmethod')?.toLowerCase()
    ?? formElement.getAttribute('method')?.toLowerCase()
    ?? 'get';
}

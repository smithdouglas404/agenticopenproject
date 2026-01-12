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

import { ConfirmationDialogProps } from '@primer/react';
import React from 'react';
import { createRoot } from 'react-dom/client';
import { ConfirmContainer } from '../react/ConfirmContainer';

type Scheme = 'primary' | 'danger';
const DEFAULT_SCHEME:Scheme = 'danger';

let hostElement:Element|null = null;

export function confirm(
  message:string,
  formElement:HTMLFormElement,
  submitter?:HTMLButtonElement|HTMLInputElement
):Promise<boolean> {
  const scheme = submitter ? inferScheme(submitter, formElement) : DEFAULT_SCHEME;

  return new Promise(resolve => {
    hostElement ??= document.createElement('div');
    if (!hostElement.isConnected) document.body.append(hostElement);

    const root = createRoot(hostElement);
    const onClose:ConfirmationDialogProps['onClose'] = (gesture) => {
      root.unmount();
      if (gesture === 'confirm') {
        resolve(true);
      } else {
        resolve(false);
      }
    };
    root.render(React.createElement(ConfirmContainer, { scheme, message, onClose }));
  });
}

function inferScheme(submitter:HTMLButtonElement | HTMLInputElement, formElement:HTMLFormElement):Scheme {
  return getFormMethod(submitter, formElement) === 'delete' ? 'danger' : 'primary';
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

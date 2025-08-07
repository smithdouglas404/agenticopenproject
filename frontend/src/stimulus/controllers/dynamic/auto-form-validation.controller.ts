/*
 * -- copyright
 * OpenProject is an open source project management software.
 * Copyright (C) 2023 the OpenProject GmbH
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
import { debounce } from 'lodash';

export default class AutoFormValidationController extends Controller<HTMLFormElement> {
  private turboRequests:TurboRequestsService;

  static values = {
    url: String,
  };

  declare readonly urlValue:string;

  async connect() {
    const context = await window.OpenProject.getPluginContext();
    this.turboRequests = context.services.turboRequests;
  }

  validateForm(event:Event) {
    const inputId = (event.currentTarget as HTMLInputElement).id; // e.g. "reminder_remind_at_date"
    const inputIdWithoutPrefix = inputId.split('_').slice(1).join('_'); // -> "remind_at_date"
    this.debouncedSubmitForm(inputIdWithoutPrefix);
  }

  private debouncedSubmitForm = debounce((inputId:string) => { this.submitForm(inputId); }, 300);

  private submitForm(inputId:string) {
    const params = new URLSearchParams({ input_id: inputId });

    void this.turboRequests.submitForm(
      this.element,
      params,
      this.urlValue,
    );
  }
}

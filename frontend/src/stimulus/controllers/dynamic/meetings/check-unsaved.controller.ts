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

import { ApplicationController, useMeta } from 'stimulus-use';
import { TurboRequestsService } from 'core-app/core/turbo/turbo-requests.service';
import { BeforeunloadController } from '../../beforeunload.controller';

export default class extends ApplicationController {
  private turboRequests:TurboRequestsService;
  private beforeUnloadController:BeforeunloadController;
  private boundBeforeUnloadHandler = this.beforeUnloadHandler.bind(this);

  static values = { unsavedChangesConfirmationMessage: String };

  declare unsavedChangesConfirmationMessageValue:string;

  static metaNames = ['csrf-token'];

  declare readonly csrfToken:string;

  async connect():Promise<void> {
    useMeta(this, { suffix: false });

    window.addEventListener('beforeunload', this.boundBeforeUnloadHandler);

    const context = await window.OpenProject.getPluginContext();
    this.turboRequests = context.services.turboRequests;
    this.beforeUnloadController = this.application.getControllerForElementAndIdentifier(document.body, 'beforeunload') as BeforeunloadController;
  }

  disconnect():void {
    window.removeEventListener('beforeunload', this.boundBeforeUnloadHandler);
  }

  handleClick(event:Event):void {
    event.preventDefault();

    const target = event.currentTarget as HTMLElement;
    const url = target.dataset.href;

    if (!url) return;

    if (this.hasUnsavedChanges()) {
      // eslint-disable-next-line no-alert
      if (window.confirm(this.unsavedChangesConfirmationMessageValue)) {
        this.sendRequest(url);
      }
    } else {
      this.sendRequest(url);
    }
  }

  private hasUnsavedChanges():boolean {
    const textInputs = Array.from(document.querySelectorAll('input[type="text"], input[type="number"]'));
    const allTextSaved = textInputs.every((input) => (input as HTMLInputElement).value.trim().length === 0);

    return !allTextSaved || window.OpenProject.pageWasEdited;
  }

  private beforeUnloadHandler(event:BeforeUnloadEvent):void {
    if (this.hasUnsavedChanges()) {
      event.preventDefault();
    }
  }

  private sendRequest(url:string):void {
    void this.turboRequests.request(url, {
      method: 'PUT',
      headers: {
        'X-CSRF-Token': this.csrfToken,
        Accept: 'text/vnd.turbo-stream.html',
      },
    });
  }
}

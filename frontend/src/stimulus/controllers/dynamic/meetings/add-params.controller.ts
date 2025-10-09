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
import { appendCollapsedState } from '../../../helpers/collapsible-helper';

export default class extends ApplicationController {
  private turboRequests:TurboRequestsService;

  static metaNames = ['csrf-token'];

  declare readonly csrfToken:string;

  // eslint-disable-next-line @typescript-eslint/no-misused-promises
  async connect() {
    useMeta(this, { suffix: false });
    const context = await window.OpenProject.getPluginContext();
    this.turboRequests = context.services.turboRequests;
  }

  intercept(event:Event):void {
    event.preventDefault();

    const target = event.currentTarget as HTMLElement;

    const confirmMessage = target.dataset.confirmMessage;
    if (confirmMessage && !window.confirm(confirmMessage)) {
      return;
    }

    const url = new URL(target.dataset.href!, window.location.origin);
    const method = target.dataset.method! || 'PUT';

    appendCollapsedState(url.searchParams);

    void this
      .turboRequests
      .request(
        url.toString(),
        {
          method,
          headers: {
            'X-CSRF-Token': this.csrfToken,
            Accept: 'text/vnd.turbo-stream.html',
          },
        },
      );
  }

  disconnect() {
    super.disconnect();
  }
}

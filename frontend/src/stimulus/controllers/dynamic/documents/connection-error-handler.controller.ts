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
import { renderStreamMessage } from '@hotwired/turbo';

export default class extends Controller {
  connect():void {
    void this.fetchErrorTemplate();
  }

  disconnect():void {
    void this.fetchRecoveryTemplate();
  }

  reloadPage():void {
    window.location.reload();
  }

  private async fetchErrorTemplate() {
    await this.fetchTemplate('error');
  }

  private async fetchRecoveryTemplate() {
    await this.fetchTemplate('recovery');
  }

  private async fetchTemplate(name:string) {
    const documentId = this.getDocumentIdFromUrl();
    if (!documentId) {
      console.error('Could not extract document ID from URL');
      return;
    }

    const url = `/documents/${documentId}/render_connection_${name}`;

    await fetch(url, {
      method: 'GET',
      headers: { Accept: 'text/vnd.turbo-stream.htm' },
    })
      .then((response:Response) => {
        if (response.ok) {
          return response.text();
        }
        return Promise.reject(new Error(`Failed to fetch ${url}: ${response.status} ${response.statusText}`));
      })
      .then((html:string) => renderStreamMessage(html))
      .catch((error:Error) => console.error('Error:', error));
  }

  private getDocumentIdFromUrl():string|null {
    const match = /\/documents\/(\d+)/.exec(window.location.pathname);
    return match ? match[1] : null;
  }
}

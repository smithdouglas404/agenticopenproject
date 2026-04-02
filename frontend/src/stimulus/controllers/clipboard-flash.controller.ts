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

/**
 * The controller listens for the 'clipboard-copy' event which is fired by
 * the @github/clipboard-copy-element when content is successfully copied.
 *
 * Usage:
 *   Add data-controller="clipboard-flash" to a container element that contains
 *   `clipboard-copy` elements. When any `clipboard-copy` element within the container
 *   successfully copies content, a flash message will be shown.
 *   Hint: if you have a fitting Rails controller for your use case, use that one to create
 *   a turbo response with a flash message. If not, you can fall back to the FlashesController.
 *
 * Values:
 *   - url: Required URL to fetch via Turbo when clipboard copy succeeds. The response
 *          should be a Turbo Stream that renders a flash message.
 *
 * Example:
 *   <div data-controller="clipboard-flash" data-clipboard-flash-url-value="/flashes/clipboard_copied_notice">
 *     <clipboard-copy value="text to copy">Copy</clipboard-copy>
 *   </div>
 */
export default class ClipboardFlashController extends Controller {
  static values = {
    url: String,
  };

  declare urlValue:string;
  declare hasUrlValue:boolean;

  private documentListener = this.handleClipboardCopy.bind(this);

  connect() {
    // Listen on document level to catch events from ActionMenu dialogs/popovers
    // which are rendered outside the controller's element
    document.addEventListener('clipboard-copy', this.documentListener);
  }

  disconnect() {
    document.removeEventListener('clipboard-copy', this.documentListener);
  }

  private handleClipboardCopy(event:Event):void {
    if (!this.hasUrlValue) { return; }

    // Check if this event has already been handled by another controller instance
    // eslint-disable-next-line no-underscore-dangle
    const customEvent = event as CustomEvent & { __clipboardFlashHandled?:boolean };
    if (customEvent.__clipboardFlashHandled) {
      return;
    }

    // Mark the event as handled to prevent other controller instances from processing it
    customEvent.__clipboardFlashHandled = true;

    // If a URL is provided, fetch it via Turbo
    if (this.hasUrlValue) {
      void fetch(this.urlValue, {
        method: 'GET',
        headers: {
          Accept: 'text/vnd.turbo-stream.html',
        },
      })
        .then((response) => response.text())
        .then((html) => {
          renderStreamMessage(html);
        })
        .catch((error) => {
          console.error('Failed to fetch URL:', error);
        });
    }
  }
}


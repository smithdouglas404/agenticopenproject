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

/**
 * Controller that shows a flash notification when clipboard-copy succeeds.
 *
 * This controller should be attached to a high-level element like <body> since
 * clipboard-copy elements can appear anywhere on the page, including inside
 * Primer ActionMenu popovers which render in the browser's top layer.
 *
 * Events from the top layer bubble through the body element, so listening on
 * this.element (when attached to body) catches all clipboard-copy events.
 *
 * Usage:
 *   Add data-controller="clipboard-flash" to the <body> tag or another high-level
 *   container element. All clipboard-copy elements on the page will automatically
 *   trigger flash notifications when clicked.
 */
export default class ClipboardFlashController extends Controller {
  private abortController:AbortController|null = null;

  connect():void {
    this.abortController = new AbortController();
    const { signal } = this.abortController;

    this.element.addEventListener('clipboard-copy', () => this.handleClipboardCopy(), { signal });
  }

  disconnect() {
    this.abortController?.abort();
    this.abortController = null;
  }

  private handleClipboardCopy():void {
    void window.OpenProject.getPluginContext().then((pluginContext) => {
      pluginContext.services.notifications.addSuccess(I18n.t('js.clipboard.copied_successful'));
    });
  }
}

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

import { ApplicationController } from 'stimulus-use';
import { buildExternalRedirectUrl, isExternalLinkCandidate, isLinkExternal } from '../helpers/external-link-helpers';

/**
 * Standalone click-interception controller for external links inside
 * ProseMirror-based editors (BlockNote/TipTap).
 *
 * Unlike the body-level ExternalLinksController, this controller does NOT
 * modify the DOM at all — no MutationObserver, no attribute writes, no href
 * rewriting. ProseMirror's internal DOMObserver re-parses and re-renders any
 * node whose attributes change, which causes infinite loops when an external
 * controller writes attributes that aren't part of the mark schema.
 *
 * TipTap's Link extension already renders `target="_blank"` and
 * `rel="noopener noreferrer nofollow"` from its mark schema defaults, so
 * those attributes are handled natively by ProseMirror.
 *
 * External link capture (`/external_redirect`) is handled purely via click
 * interception: when the user clicks an external link, we preventDefault and
 * window.open the redirect URL. The document model retains original URLs,
 * Yjs collaboration is unaffected, and no re-render loops occur.
 */
export default class ProseMirrorExternalLinksController extends ApplicationController {
  static values = {
    enabled: Boolean,
  };

  declare readonly enabledValue:boolean;

  private clickAbortController?:AbortController;

  connect() {
    this.clickAbortController = new AbortController();
    const { signal } = this.clickAbortController;

    this.element.addEventListener('click', this.interceptExternalClick, { signal, capture: true });
    this.element.addEventListener('auxclick', this.interceptExternalClick, { signal, capture: true });
  }

  disconnect() {
    this.clickAbortController?.abort();
  }

  /**
   * Handles both left-click (`click`) and middle-click (`auxclick` with
   * button 1). Right-clicks and other auxiliary buttons are ignored — they
   * open the browser's native context menu, which reads href directly from
   * the DOM and cannot be intercepted via JavaScript.
   */
  private interceptExternalClick = (event:MouseEvent) => {
    if (!this.enabledValue) return;
    // auxclick fires for non-primary mouse buttons (middle, right, back, forward)
    if (event.type === 'auxclick' && !isMiddleClick(event)) return;

    const target = event.composedPath()[0] as Element | undefined;
    const link = target?.closest('a');
    if (!link) return;
    if (!isExternalLinkCandidate(link)) return;
    if (!isLinkExternal(link)) return;
    if (link.dataset.allowExternalLink) return;

    event.preventDefault();
    event.stopPropagation();

    window.open(buildExternalRedirectUrl(link.href), '_blank', 'noopener,noreferrer');
  };
}

/**
 * Returns true when the event is a middle-click (mouse button 1).
 * Middle-clicks trigger the `auxclick` event alongside right-clicks and
 * other auxiliary buttons — this predicate distinguishes the ones we want
 * to intercept (middle-click opens in new tab) from those we don't
 * (right-click opens native context menu).
 */
function isMiddleClick(event:MouseEvent) {
  return event.button === 1;
}

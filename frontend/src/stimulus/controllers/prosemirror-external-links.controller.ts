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

import { attributeTokenList } from 'core-app/shared/helpers/dom-helpers';
import ExternalLinksController from './external-links.controller';

/**
 * Specialised ExternalLinksController for ProseMirror-based editors (BlockNote/TipTap).
 *
 * ProseMirror maintains an internal document model and a MutationObserver
 * (DOMObserver) that watches every attribute change inside its contenteditable
 * region. When an attribute is changed on a DOM node, ProseMirror re-parses
 * the node against its schema and re-renders it — which creates a *new* DOM
 * node, triggering our own MutationObserver all over again.
 *
 * Two categories of attribute writes cause problems:
 *
 * 1. **Attributes not in the Link mark schema** (e.g. `aria-describedby`):
 *    ProseMirror strips them on re-render because they aren't in the schema,
 *    producing a new node without the attribute → our observer re-adds it →
 *    infinite loop.
 *
 * 2. **Redundant writes to schema-recognised attributes** (e.g. `target`,
 *    `rel`): even though ProseMirror keeps these, the write itself triggers
 *    the DOMObserver → re-parse → re-render (new node) → our observer fires
 *    again → unconditional write → loop.  With many links (e.g. pasting rich
 *    text) this cascade freezes the browser.
 *
 * This subclass overrides two methods to address both:
 *
 * - `updateBlankLink`: skips `aria-describedby` entirely inside
 *   `contenteditable` (category 1).
 * - `updateExternalLink`: guards every DOM write with an idempotency check
 *   so no attribute is touched when it already holds the correct value
 *   (category 2).
 */
export default class ProseMirrorExternalLinksController extends ExternalLinksController {
  protected updateBlankLink(link:HTMLAnchorElement) {
    // aria-describedby is not in ProseMirror's Link mark schema, so adding
    // it triggers a re-parse → strip → re-add loop. Skip it inside the
    // contenteditable region; the body-level controller still handles it
    // for links outside the editor.
    if (link.closest('[contenteditable="true"]')) return;

    super.updateBlankLink(link);
  }

  protected updateExternalLink(link:HTMLAnchorElement) {
    // Only write when the value actually changes, to avoid triggering
    // ProseMirror's DOMObserver unnecessarily.
    if (link.target !== '_blank') link.target = '_blank';

    const rel = attributeTokenList(link, 'rel');
    if (!rel.contains('noopener') || !rel.contains('noreferrer')) {
      rel.add('noopener', 'noreferrer');
    }

    // Capture external links through redirect page
    if (this.enabledValue && !link.dataset.allowExternalLink && !link.href.includes('/external_redirect?url=')) {
      const originalHref = link.href;
      const basePath = window.appBasePath ?? '';
      link.href = `${basePath}/external_redirect?url=${encodeURIComponent(originalHref)}`;
    }
  }
}

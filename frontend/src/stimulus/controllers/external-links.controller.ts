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

import { Controller } from '@hotwired/stimulus';
import { MutationHelper } from 'core-stimulus/helpers/mutation-helper';

const BLANK_LINK_QUERY = 'a[target="_blank"]';
const BLANK_LINK_DESCRIPTION_ID = 'open-blank-target-link-description';

/**
 * Observes all external links and sets their ARIA `describedby` attribute to
 * {BLANK_LINK_DESCRIPTION_ID} - this element should exist in the DOM and
 * provide localized text content along the lines of "Open link in a new tab".
 *
 * The goal is to make users of Assistive Technology aware that they may have to
 * switch tabs on clicking a link.
 *
 * We consider links with a `target` attribute set to "_blank" as "external".
 */
export default class ExternalLinksController extends Controller<HTMLBodyElement> {
  private helper = MutationHelper.forAttributes(
    this.element,
    BLANK_LINK_QUERY,
    applyLinkDescription,
    { attributeFilter: ['target'], debounceMs: 50 }
  );

  connect() {
    this.helper.observe();
  }

  disconnect() {
    this.helper.disconnect();
  }
}

function applyLinkDescription(link:HTMLAnchorElement) {
  if (!link.hasAttribute('aria-describedby')) {
    link.setAttribute('aria-describedby', BLANK_LINK_DESCRIPTION_ID);
  }
}

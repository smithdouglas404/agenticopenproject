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
import { useMutation } from 'stimulus-use';

const BLANK_LINK_QUERY = 'a[target="_blank"]';
const BLANK_LINK_DESCRIPTION_ID = 'open-blank-target-link-description';

const isElement = (node:Node):node is Element => node.nodeType === Node.ELEMENT_NODE;
const isBlankLink = (elem:Element):elem is HTMLAnchorElement => elem.matches(BLANK_LINK_QUERY);

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
export default class ExternalLinksController extends ApplicationController {
  connect() {
    useMutation(this, { attributes: true, childList: true, subtree: true, attributeFilter: ['target'] });

    // initial pass
    document.querySelectorAll(BLANK_LINK_QUERY).forEach(applyLinkDescription);
  }

  mutate(mutations:MutationRecord[]) {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (isElement(node)) {
          // added element itself is a blank link
          if (isBlankLink(node)) {
            applyLinkDescription(node);
          }
          // added sub-trees
          node.querySelectorAll(BLANK_LINK_QUERY).forEach(applyLinkDescription);
        }
      });

      // attribute changes
      if (
        mutation.type === 'attributes' &&
        mutation.attributeName === 'target' &&
        isElement(mutation.target) &&
        isBlankLink(mutation.target)
      ) {
        applyLinkDescription(mutation.target);
      }
    });
  }
}

function applyLinkDescription(link:HTMLAnchorElement) {
  const existingValue = link.getAttribute('aria-describedby');
  if (!existingValue) {
    link.setAttribute('aria-describedby', BLANK_LINK_DESCRIPTION_ID);
  } else if (!existingValue.split(/\s+/).includes(BLANK_LINK_DESCRIPTION_ID)) {
    link.setAttribute('aria-describedby', existingValue + ' ' + BLANK_LINK_DESCRIPTION_ID);
  }
}

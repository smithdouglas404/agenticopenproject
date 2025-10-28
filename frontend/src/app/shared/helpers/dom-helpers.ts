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

export const getNodeIndex = (element:Element) => Array.from(element.parentNode!.children).indexOf(element);

export const toggleElement = (element:HTMLElement, value?:boolean) => {
  if (typeof value === 'undefined') {
    element.hidden = !element.hidden;
  } else {
    element.hidden = !value;
  }
};

export const showElement = (element:HTMLElement) => toggleElement(element, true);

export const hideElement = (element:HTMLElement) => toggleElement(element, false);

/**
 * Mimics jQuery(':visible')
 */
export function isVisible(elem:HTMLElement|null) {
  if (!elem) return false;

  // Check if element is in the DOM
  if (!document.contains(elem)) return false;

  // Check if dimensions are visible
  return !!(
    elem.offsetWidth
    || elem.offsetHeight
    || elem.getClientRects().length
  );
}

export function queryVisible<T extends HTMLElement = HTMLElement>(selector:string, node:Element|Document = document) {
  return Array.from(node.querySelectorAll<T>(selector)).filter(isVisible);
}

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

/**
 * Toggles the visibility of an HTMLElement using `hidden` property.
 *
 * @note This is the recommended, modern approach. It is also accessible.
 * @param element the element to be toggled.
 * @param value force visibility (optional): `true` to show the element/`false` to hide the element.
 */
export function toggleElement(element:HTMLElement, value?:boolean) {
  if (typeof value === 'undefined') {
    element.hidden = !element.hidden;
  } else {
    element.hidden = !value;
  }
};

/**
 * Toggles the visibility of an Element using a CSS class.
 * Also takes care of setting `aria-hidden` attribute for accessibility.
 *
 * @param element the element to be toggled.
 * @param className the CSS class name to use.
 * @param value force visibility (optional): `true` to show the element/`false` to hide the element.
 */
export function toggleElementByClass(element:Element, className:string, value?:boolean) {
  let hiddenValue:boolean;
  if (typeof value === 'undefined') {
    hiddenValue = element.classList.toggle(className);
  } else {
    hiddenValue = element.classList.toggle(className, !value);
  }
  element.setAttribute('aria-hidden', hiddenValue.toString());
};

/**
 * Toggles the visibility of an HTMLElement using `visibility` style property.
 *
 * @param element the element to be toggled.
 * @param value force visibility (optional): `true` to show the element/`false` to hide the element.
 */
export function toggleElementByVisibility(element:HTMLElement, value?:boolean) {
  value ??= element.style.getPropertyValue('visibility') !== 'visible';
  element.style.setProperty('visibility', value ? 'visible' : 'hidden');
};

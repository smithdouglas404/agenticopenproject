/*
 * -- copyright
 * OpenProject is an open source project management software.
 * Copyright (C) 2023 the OpenProject GmbH
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

import { ICKEditorInstance } from 'core-app/shared/components/editor/components/ckeditor/ckeditor.types';

/**
 * Returns a collapsed DOM Range at the given viewport coordinates.
 * Prefers the modern `caretPositionFromPoint` API, falls back to the
 * deprecated `caretRangeFromPoint` for browsers that do not support it yet.
 */
export function caretRangeFromPoint(x:number, y:number):Range|null {
  if ('caretPositionFromPoint' in document) {
    const pos = document.caretPositionFromPoint(x, y);
    if (pos) {
      const range = document.createRange();
      range.setStart(pos.offsetNode, pos.offset);
      range.collapse(true);
      return range;
    }
    return null;
  }
  return (document as Document).caretRangeFromPoint?.(x, y) ?? null;
}

export function retrieveCkEditorInstance(element:HTMLElement):ICKEditorInstance|undefined {
  return getEditableElement(element)?.ckeditorInstance;
}

function getEditableElement(element:HTMLElement):HTMLElement|null {
  return element.querySelector<HTMLElement>('.ck-editor__editable_inline');
}

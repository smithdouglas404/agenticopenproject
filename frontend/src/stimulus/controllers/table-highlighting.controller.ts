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

export default class TableHighlightingController extends Controller<HTMLTableElement> {
  private thead:HTMLTableSectionElement|null = null;
  private colgroup:HTMLTableColElement|null = null;

  connect():void {
    this.thead = this.element.tHead;
    this.colgroup = this.element.querySelector('colgroup');

    if (!this.thead || !this.colgroup) {
      return;
    }

    this.thead.addEventListener('mouseenter', this.onEnter, true);
    this.thead.addEventListener('mouseleave', this.onLeave, true);
  }

  disconnect():void {
    if (!this.thead) return;

    this.thead.removeEventListener('mouseenter', this.onEnter, true);
    this.thead.removeEventListener('mouseleave', this.onLeave, true);

    this.thead = null;
    this.colgroup = null;
  }

  private onEnter = (event:Event):void => {
    const col = this.resolveColumn(event.target);
    col?.classList.add('hover');
  };

  private onLeave = (event:Event):void => {
    const col = this.resolveColumn(event.target);
    col?.classList.remove('hover');
  };

  private resolveColumn(target:EventTarget|null):HTMLTableColElement|null {
    if (!(target instanceof HTMLElement)) {
      return null;
    }

    const th = target.closest('th');
    if (!th || !this.colgroup) {
      return null;
    }

    const index = th.cellIndex;
    if (index < 0) {
      return null;
    }

    const col = this.colgroup.children.item(index) as HTMLTableColElement|null;
    if (!col || col.dataset.highlight === 'false') {
      return null;
    }

    return col;
  }
}

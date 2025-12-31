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

import {controller} from '@github/catalyst';

@controller
export class DataTableElement extends HTMLElement {

  constructor() {
    super();
  }

  connectedCallback() {
    sortTableByAriaSort(this.table);
  }

  toggleSort(event:MouseEvent) {
    const header = (event.target as Element).closest('th')!;
    const ariaSort = header.getAttribute('aria-sort');
    const sortAscendingIcon = header.querySelector('.TableSortIcon--ascending');
    const sortDescendingIcon = header.querySelector('.TableSortIcon--descending');

    if (ariaSort === 'descending') {
      header.setAttribute('aria-sort', 'ascending');
      sortAscendingIcon?.classList.remove('d-none');
      sortDescendingIcon?.classList.add('d-none'); 
    } else {
      header.setAttribute('aria-sort', 'descending');
      sortDescendingIcon?.classList.remove('d-none');
      sortAscendingIcon?.classList.add('d-none'); 
    }

    const siblings = [...header.parentElement!.children].filter(el => el !== header);
    siblings.forEach((sibling:HTMLElement) => {
      resetSort(sibling);
    });

    sortTableByAriaSort(this.table);
  }

  get table():HTMLTableElement {
    return this.querySelector('table')!;
  }
}


function resetSort(th:HTMLElement) {
  th.removeAttribute('aria-sort');
  const sortAscendingIcon = th.querySelector('.TableSortIcon--ascending');
  const sortDescendingIcon = th.querySelector('.TableSortIcon--descending');
  sortAscendingIcon?.classList.remove('d-none');
  sortDescendingIcon?.classList.add('d-none'); 
}


//if (!customElements.get('data-table')) {
//  customElements.define('data-table', DataTableElement);
//}

function sortTableByAriaSort(table:HTMLTableElement) {
  const headers = Array.from(table.querySelectorAll('thead th'));
  const tbody = table.querySelector('tbody')!;

  const sortedHeader = headers.find(th =>
    th.getAttribute('aria-sort') === 'ascending' ||
    th.getAttribute('aria-sort') === 'descending'
  );

  if (!sortedHeader) return;

  const columnIndex = headers.indexOf(sortedHeader);
  const direction = sortedHeader.getAttribute('aria-sort');

  const rows = Array.from(tbody.querySelectorAll('tr'));

  const sortedRows = rows.sort((a, b) => {
    const aText = a.children[columnIndex].textContent?.trim() ?? '';
    const bText = b.children[columnIndex].textContent?.trim() ?? '';

    const aNum = parseFloat(aText);
    const bNum = parseFloat(bText);

    const valueA = isNaN(aNum) ? aText : aNum;
    const valueB = isNaN(bNum) ? bText : bNum;

    if (valueA < valueB) return direction === 'ascending' ? -1 : 1;
    if (valueA > valueB) return direction === 'ascending' ? 1 : -1;
    return 0;
  });

  tbody.append(...sortedRows);
}

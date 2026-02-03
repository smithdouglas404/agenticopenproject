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

import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ['filterInput', 'project', 'counter'];

    declare readonly filterInputTarget:HTMLInputElement;
    declare readonly projectTargets:HTMLElement[];
    declare readonly counterTargets:HTMLElement[];

    filter():void {
        const query = this.filterInputTarget.value.toLowerCase().trim();

        this.projectTargets.forEach((project) => {
            const name = project.dataset.projectName?.toLowerCase() ?? '';
            const key = project.dataset.projectKey?.toLowerCase() ?? '';
            const wrapper:HTMLElement = project.closest('.FormControl-checkbox-wrap')!;
            wrapper.style.display = (query === '' || name.includes(query) || key.includes(query)) ? '' : 'none';
        });
    }

    clear():void {
        this.filterInputTarget.value = '';
        this.filter();
    }

    connect():void {
        this.updateCounter();
        // Listen for changes on all checkboxes
        this.element.addEventListener('change', (event) => {
             const target = event.target as HTMLElement;
            if (target.tagName === 'INPUT' && target.getAttribute('type') === 'checkbox') {
                this.updateCounter();
            }
        });
    }

    updateCounter():void {
        const checkboxes = this.element.querySelectorAll<HTMLInputElement>('input[type="checkbox"]');
        const checkedCount = Array.from(checkboxes).filter(cb => cb.checked).length.toString();
        this.counterTargets.forEach(counter => {
            counter.textContent = checkedCount;
            counter.setAttribute('title', checkedCount);
        });
    }

    checkAll(event:Event):void {
        event.preventDefault();
        const checkboxes = this.element.querySelectorAll<HTMLInputElement>('input[type="checkbox"]');
        checkboxes.forEach(checkbox => {
            const wrapper:HTMLElement = checkbox.closest('.FormControl-checkbox-wrap')!;
            if (wrapper.style.display !== 'none') {
                checkbox.checked = true;
            }
        });
        this.updateCounter();
    }

    uncheckAll(event:Event):void {
        event.preventDefault();
        const checkboxes = this.element.querySelectorAll<HTMLInputElement>('input[type="checkbox"]');
        checkboxes.forEach(checkbox => {
            const wrapper:HTMLElement = checkbox.closest('.FormControl-checkbox-wrap')!;
            if (wrapper.style.display !== 'none') {
                checkbox.checked = false;
            }
        });
        this.updateCounter();
    }
}

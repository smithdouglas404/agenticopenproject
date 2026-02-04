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
import {
  NgOption,
  NgSelectComponent,
} from '@ng-select/ng-select';

/**
 * Stimulus Controller adding behavior to Admin > Backlogs page.
 */
export default class BacklogsSettings extends Controller<HTMLElement> {
  static targets = ['storyTypes', 'taskType'];

  declare readonly storyTypesTarget:HTMLElement;
  declare readonly taskTypeTarget:HTMLElement;
  declare readonly hasStoryTypesTarget:boolean;
  declare readonly hasTaskTypeTarget:boolean;

  private isUpdating = false;

  storyTypesTargetConnected(target:HTMLElement) {
    target.addEventListener('change', this.onStoryTypesActivated);
  }

  storyTypesTargetDisconnected(target:HTMLElement) {
    target.removeEventListener('change', this.onStoryTypesActivated);
  }

  taskTypeTargetConnected(target:HTMLElement) {
    target.addEventListener('change', this.onTaskTypeActivated);
  }

  taskTypeTargetDisconnected(target:HTMLElement) {
    target.removeEventListener('change', this.onTaskTypeActivated);
  }

  private onStoryTypesActivated = (_event:CustomEvent) => {
    if (this.isUpdating || !this.hasStoryTypesTarget) return;

    const taskAutocomplete = this.autocompleterElementFor(this.taskTypeTarget);
    const storyAutocomplete = this.autocompleterElementFor(this.storyTypesTarget);

    if (!taskAutocomplete || !storyAutocomplete) return;

    this.isUpdating = true;
    try {
      this.syncAutocompleters(storyAutocomplete, taskAutocomplete);
    } finally {
      this.isUpdating = false;
    }
  };

  private onTaskTypeActivated = (_event:CustomEvent) => {
    if (this.isUpdating || !this.hasTaskTypeTarget) return;

    const taskAutocomplete = this.autocompleterElementFor(this.taskTypeTarget);
    const storyAutocomplete = this.autocompleterElementFor(this.storyTypesTarget);

    if (!taskAutocomplete || !storyAutocomplete) return;

    this.isUpdating = true;
    try {
      this.syncAutocompleters(taskAutocomplete, storyAutocomplete);
    } finally {
      this.isUpdating = false;
    }
  };

  /**
   * Syncs two autocompleters - ensuring selections are mutually exclusive.
   *
   * @param source source autocompleter
   * @param target target autocompleter
   */
  private syncAutocompleters(source:NgSelectComponent, target:NgSelectComponent) {
    const sourceSelectedIds = new Set(
      source.selectedItems
        .map((item) => item.value.id)
        .filter((id) => id != null)
    );

    const updatedItems = target.items?.map((targetItem:NgOption) => {
      const itemId = targetItem.id;

      if (!itemId) return targetItem;

      const shouldBeDisabled = sourceSelectedIds.has(itemId);
      if (targetItem.disabled !== shouldBeDisabled) {
        return {
          ...targetItem,
          disabled: shouldBeDisabled
        };
      }

      return targetItem;
    });

    if (!updatedItems) return;

    target.itemsList.setItems(updatedItems);
  }

  private autocompleterElementFor(el:HTMLElement):NgSelectComponent|null {
    const ngSelectElement = el.querySelector('ng-select');
    if (!ngSelectElement) return null;

    // eslint-disable-next-line @typescript-eslint/no-unsafe-return,@typescript-eslint/no-unsafe-call,@typescript-eslint/no-unsafe-member-access
    return (window as any).ng.getComponent(ngSelectElement) ?? null;
  }
}

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
 * Ensures that story types and task types are mutually exclusive.
 */
export default class BacklogsSettings extends Controller<HTMLElement> {
  static targets = ['storyTypes', 'taskType'];

  declare readonly storyTypesTarget:HTMLElement;
  declare readonly taskTypeTarget:HTMLElement;
  declare readonly hasStoryTypesTarget:boolean;
  declare readonly hasTaskTypeTarget:boolean;

  private isUpdating = false;

  storyTypesTargetConnected(target:HTMLElement) {
    target.addEventListener('change', this.onStoryTypesChanged);
  }

  storyTypesTargetDisconnected(target:HTMLElement) {
    target.removeEventListener('change', this.onStoryTypesChanged);
  }

  taskTypeTargetConnected(target:HTMLElement) {
    target.addEventListener('change', this.onTaskTypeChanged);
  }

  taskTypeTargetDisconnected(target:HTMLElement) {
    target.removeEventListener('change', this.onTaskTypeChanged);
  }

  private onStoryTypesChanged = () => {
    if (this.isUpdating || !this.hasTaskTypeTarget) return;

    this.syncDisabledOptions(this.storyTypesTarget, this.taskTypeTarget);
  };

  private onTaskTypeChanged = () => {
    if (this.isUpdating || !this.hasStoryTypesTarget) return;

    this.syncDisabledOptions(this.taskTypeTarget, this.storyTypesTarget);
  };

  /**
   * Syncs disabled options between two autocompleters.
   * Selected values in the source autocompleter will be disabled in the target.
   *
   * @param sourceTarget The autocompleter whose selections should disable options in the target
   * @param targetTarget The autocompleter whose options should be disabled
   */
  private syncDisabledOptions(sourceTarget:HTMLElement, targetTarget:HTMLElement) {
    this.isUpdating = true;
    try {
      const sourceNgSelect = this.getNgSelectComponent(sourceTarget);
      const targetNgSelect = this.getNgSelectComponent(targetTarget);

      if (!sourceNgSelect || !targetNgSelect) {
        return;
      }

      this.syncAutocompleters(sourceNgSelect, targetNgSelect);
    } finally {
      this.isUpdating = false;
    }
  }

  /**
   * Gets the NgSelectComponent instance from an op-autocompleter element.
   */
  private getNgSelectComponent(target:HTMLElement):NgSelectComponent|null {
    // Access the ng-select instance stored by op-autocompleter component
    // eslint-disable-next-line @typescript-eslint/no-unsafe-return,@typescript-eslint/no-unsafe-member-access
    return (target as any).ngSelectComponentInstance ?? null;
  }

  /**
   * Syncs two ng-select autocompleters - ensuring selections are mutually exclusive.
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

    // Directly mutate the items array to ensure ng-select updates properly
    let hasChanges = false;
    target.itemsList.items.forEach((targetItem:NgOption) => {
      // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
      const itemId = targetItem.value?.id;

      if (!itemId) return;

      const shouldBeDisabled = sourceSelectedIds.has(itemId);
      if (targetItem.disabled !== shouldBeDisabled) {
        targetItem.disabled = shouldBeDisabled;
        hasChanges = true;
      }
    });

    // Force ng-select to re-render if we made changes
    if (hasChanges) {
      target.detectChanges();
    }
  }
}

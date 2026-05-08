/*
 * OpenProject is an open source project management software.
 * Copyright (C) the OpenProject GmbH
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License version 3.
 *
 * See COPYRIGHT and LICENSE files for more details.
 */

import { Controller } from '@hotwired/stimulus';

const STORAGE_KEY = 'openProject-project-select-display-mode';

export default class HeaderProjectSelectController extends Controller {
  connect():void {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored && stored !== 'all') {
      // Defer until after all Stimulus controllers have connected (including
      // filterable-tree-view), so its click listener is already set up when
      // we programmatically activate the stored filter mode.
      setTimeout(() => {
        this.element
          .querySelector<HTMLElement>(`[data-name="${stored}"]`)
          ?.click();
      }, 0);
    }

    this.element.addEventListener('click', this.onFilterModeClick);
  }

  disconnect():void {
    this.element.removeEventListener('click', this.onFilterModeClick);
  }

  private onFilterModeClick = (event:MouseEvent):void => {
    const button = (event.target as HTMLElement).closest<HTMLElement>('[data-name]');
    if (button?.dataset.name) {
      localStorage.setItem(STORAGE_KEY, button.dataset.name);
    }
  };
}

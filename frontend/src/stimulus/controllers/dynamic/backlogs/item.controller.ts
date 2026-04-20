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

import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';
import type { TurboVisitEvent } from '@hotwired/turbo';

const DRAG_MOVEMENT_THRESHOLD = 5;

export default class ItemController extends Controller<HTMLElement> implements EventListenerObject {
  static values = {
    id: Number,
    splitUrl: String,
    fullUrl: String,
  };

  static classes = ['selected'];

  declare idValue:number;
  declare splitUrlValue:string;
  declare fullUrlValue:string;
  declare readonly selectedClass:string;

  private abortController:AbortController|null = null;
  private clickTimeout:number|null = null;
  private activePointerId:number|null = null;
  private pointerOrigin:{ x:number; y:number }|null = null;
  private suppressNextClick = false;

  connect():void {
    this.abortController = new AbortController();
    const { signal } = this.abortController;

    this.element.addEventListener('click', this, { signal });
    this.element.addEventListener('dblclick', this, { signal });
    this.element.addEventListener('keydown', this, { signal });
    this.element.addEventListener('pointerdown', this, { signal });
    this.element.addEventListener('pointermove', this, { signal });
    this.element.addEventListener('pointerup', this, { signal });
    this.element.addEventListener('pointercancel', this, { signal });
    document.addEventListener('turbo:visit', ((event:TurboVisitEvent) => {
      this.syncSelectionFromUrl(event.detail.url);
    }) as EventListener, { signal });

    this.syncSelectionFromUrl(window.location.href);
  }

  disconnect():void {
    this.abortController?.abort();
    this.abortController = null;

    if (this.clickTimeout !== null) {
      clearTimeout(this.clickTimeout);
      this.clickTimeout = null;
    }

    this.resetPointerState();
    this.suppressNextClick = false;
  }

  handleEvent(event:Event):void {
    switch (event.type) {
      case 'click':
        this.onClick(event as MouseEvent);
        break;
      case 'dblclick':
        this.onDoubleClick(event as MouseEvent);
        break;
      case 'keydown':
        this.onKeydown(event as KeyboardEvent);
        break;
      case 'pointerdown':
        this.onPointerDown(event as PointerEvent);
        break;
      case 'pointermove':
        this.onPointerMove(event as PointerEvent);
        break;
      case 'pointerup':
      case 'pointercancel':
        this.onPointerEnd(event as PointerEvent);
        break;
    }
  }

  markAsSelected():void {
    this.element.classList.add(this.selectedClass);
    this.element.setAttribute('aria-current', 'true');
  }

  unmarkAsSelected():void {
    this.element.classList.remove(this.selectedClass);
    this.element.removeAttribute('aria-current');
  }

  private syncSelectionFromUrl(locationUrl:string):void {
    const { pathname } = new URL(locationUrl, window.location.origin);
    const [, id] = /\/details\/(\d+)/.exec(pathname) ?? [];

    if (id !== undefined && Number(id) === this.idValue) {
      this.markAsSelected();
    } else {
      this.unmarkAsSelected();
    }
  }

  private onClick(event:MouseEvent):void {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;

    if (this.suppressNextClick) {
      this.suppressNextClick = false;
      return;
    }

    if (this.shouldIgnoreMouseTarget(target)) return;
    if (this.clickTimeout !== null) return;

    this.clickTimeout = window.setTimeout(() => {
      this.clickTimeout = null;
      this.openSplitPane();
    }, 250);
  }

  private onDoubleClick(event:MouseEvent):void {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;
    if (this.shouldIgnoreMouseTarget(target)) return;

    if (this.clickTimeout !== null) {
      clearTimeout(this.clickTimeout);
      this.clickTimeout = null;
    }

    this.openFullPane();
  }

  private onKeydown(event:KeyboardEvent):void {
    if (event.key !== 'Enter') return;

    const target = event.target;
    if (!(target instanceof HTMLElement)) return;
    if (this.shouldIgnoreKeyboardTarget(target)) return;

    event.preventDefault();
    if (event.shiftKey) {
      this.openFullPane();
    } else {
      this.openSplitPane();
    }
  }

  private onPointerDown(event:PointerEvent):void {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;
    if (this.shouldIgnoreMouseTarget(target)) return;

    this.activePointerId = event.pointerId;
    this.pointerOrigin = { x: event.clientX, y: event.clientY };
    this.suppressNextClick = false;
  }

  private onPointerMove(event:PointerEvent):void {
    if (this.activePointerId !== event.pointerId || this.pointerOrigin === null) return;
    if (this.suppressNextClick) return;

    const deltaX = event.clientX - this.pointerOrigin.x;
    const deltaY = event.clientY - this.pointerOrigin.y;

    if (Math.hypot(deltaX, deltaY) >= DRAG_MOVEMENT_THRESHOLD) {
      this.suppressNextClick = true;
    }
  }

  private onPointerEnd(event:PointerEvent):void {
    if (this.activePointerId !== event.pointerId) return;

    this.resetPointerState();
  }

  private resetPointerState():void {
    this.activePointerId = null;
    this.pointerOrigin = null;
  }

  private openSplitPane():void {
    Turbo.visit(this.splitUrlValue, { frame: 'content-bodyRight', action: 'advance' });
  }

  private openFullPane():void {
    Turbo.visit(this.fullUrlValue, { frame: '_top' });
  }

  private shouldIgnoreMouseTarget(target:HTMLElement):boolean {
    return [
      'a',
      'button',
      'clipboard-copy',
      'input',
      'textarea',
      'select',
      "[contenteditable='true']",
    ].some((selector) => target.closest(selector) !== null);
  }

  private shouldIgnoreKeyboardTarget(target:HTMLElement):boolean {
    return this.shouldIgnoreMouseTarget(target);
  }
}

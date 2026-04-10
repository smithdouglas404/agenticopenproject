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

/**
 * Primer `<action-menu>` with `src` (via `Primer::Alpha::ActionMenu`) lazy loads
 * the menu items via `<include-fragment>`.
 * It registers `include-fragment-replaced` only in `connectedCallback`, while Turbo
 * Idiomorph can leave the same `<action-menu>` host connected while swapping
 * in a new `<include-fragment>`. Since the `<action-menu>` is not replaced, the fragment
 * replaced event is never fired, the component will stay in a loading state after morph.
 *
 * Replacing each affected `<action-menu>` host forces `connectedCallback` and
 * a correct listener.
 * TODO: This fix should be extended to other deferred primer components, including
 * `turbo:before-frame-morph`, `turbo:morph` (full page morph) events too.
 */

interface TurboBeforeStreamRenderDetail {
  newStream:Element;
  render:(stream:Element) => Promise<void>;
}

function remountDeferredPrimerActionMenu(root:ParentNode):void {
  root.querySelectorAll('action-menu').forEach((menu) => {
    if (!menu.querySelector('include-fragment[src]')) {
      return;
    }
    const clone = menu.cloneNode(true) as HTMLElement;
    menu.replaceWith(clone);
  });
}

export function registerActionMenuStreamAction():void {
  document.addEventListener('turbo:before-stream-render', (event:Event) => {
    const { detail } = event as CustomEvent<TurboBeforeStreamRenderDetail>;
    const stream = detail?.newStream as HTMLElement | undefined;
    if (!stream) {
      return;
    }

    if (stream.getAttribute('action') !== 'replace' ||
        stream.getAttribute('method') !== 'morph') {
      return;
    }

    const targetId = stream.getAttribute('target');
    if (!targetId) {
      return;
    }

    const targetElement = document.getElementById(targetId);
    if (!targetElement) {
      return;
    }

    if (!targetElement.querySelector('action-menu include-fragment[src]')) {
      return;
    }

    const originalRender = detail.render;
    detail.render = async (streamElement) => {
      await originalRender(streamElement);
      remountDeferredPrimerActionMenu(targetElement);
    };
  });
}

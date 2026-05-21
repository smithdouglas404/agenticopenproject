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
import { FrameElement } from '@hotwired/turbo';
import { HalEventsService } from 'core-app/features/hal/services/hal-events.service';
import { filter, Subscription } from 'rxjs';

export default class BacklogsController extends Controller<HTMLElement> {
  private service:HalEventsService|null = null;
  private subscription:Subscription|null = null;
  private abortController:AbortController|null = null;

  // eslint-disable-next-line @typescript-eslint/no-misused-promises
  async connect() {
    const { services: { halEvents } } = await window.OpenProject.getPluginContext();

    this.service = halEvents;
    this.subscription = this.service.aggregated$('WorkPackage')
      .pipe(filter((events) => events.some((event) => event.eventType === 'updated')))
      .subscribe(() => { this.refreshList(); });

    this.abortController = new AbortController();
    const { signal } = this.abortController;

    document.addEventListener('turbo:before-morph-element', (event:Event) => {
      const morphEvent = event as CustomEvent<{ newElement:Element }>;
      const el = morphEvent.target as Element;
      if (el.tagName !== 'TURBO-FRAME') return;

      const newSrc = morphEvent.detail.newElement?.getAttribute('src');
      if (el.hasAttribute('complete') && el.getAttribute('src')?.endsWith(newSrc!)) {
        morphEvent.preventDefault();
      }
    }, { signal });
  }

  disconnect() {
    this.subscription?.unsubscribe();
    this.subscription = null;
    this.service = null;
    this.abortController?.abort();
    this.abortController = null;
  }

  private refreshList() {
    void this.listElement.reload();
  }

  private get listElement() {
    return this.element.querySelector<FrameElement>('#backlogs_container')!;
  }
}

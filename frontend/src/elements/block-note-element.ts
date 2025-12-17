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

import { User } from '@blocknote/core/comments';
import { HocuspocusProvider } from '@hocuspocus/provider';
import { Application } from '@hotwired/stimulus';
import ConnectionErrorHandlerController from 'core-stimulus/controllers/dynamic/documents/connection-error-handler.controller';
import { LiveCollaborationManager } from 'core-stimulus/helpers/live-collaboration-helpers';
import { ShadowDomWrapper } from 'op-blocknote-extensions';
import React from 'react';
import type { Root } from 'react-dom/client';
import { createRoot } from 'react-dom/client';
import { environment } from '../environments/environment';
import OpBlockNoteContainer from '../react/OpBlockNoteContainer';
import { blockNoteStylesheet } from './block-note-element-styles';
import { primerStyleSheet } from './shadow-dom-styles';

class BlockNoteElement extends HTMLElement {
  private mount:HTMLDivElement;
  private stimulusMount:HTMLDivElement;
  private reactRoot:Root|null = null;
  private stimulusApplication:Application|null = null;

  constructor() {
    super();

    const shadowRoot = this.attachShadow({ mode: 'open' });
    this.stimulusMount = document.createElement('div');
    this.stimulusMount.id = 'documents-show-edit-view-connection-error-notice-component';
    // Note: data-controller is added/removed by React based on connection error state
    this.mount = document.createElement('div');
    shadowRoot.appendChild(this.stimulusMount);
    shadowRoot.appendChild(this.mount);

    const blockNoteStylesheetUrl = this.getAttribute('blocknote-stylesheet-url');
    if (blockNoteStylesheetUrl) {
      const link = document.createElement('link');
      link.setAttribute('rel', 'stylesheet');
      link.setAttribute('href', blockNoteStylesheetUrl);
      shadowRoot.appendChild(link);
    }

    // Apply Primer styles (for components like Banner) and BlockNote-specific styles
    // Using adoptedStyleSheets for synchronous application (no FOUC)
    shadowRoot.adoptedStyleSheets = [primerStyleSheet, blockNoteStylesheet];
  }

  connectedCallback() {
    this.stimulusApplication = Application.start(this.stimulusMount);
    this.stimulusApplication.register('documents--connection-error-handler', ConnectionErrorHandlerController);
    this.stimulusApplication.debug = !environment.production;
    this.stimulusApplication.handleError = (error, message, detail) => {
      console.warn(error, message, detail);
    };

    this.reactRoot = createRoot(this.mount);

    const collaborationEnabled = this.getAttribute('collaboration-enabled') === 'true';
    if (collaborationEnabled) {
      LiveCollaborationManager.onReady((hocuspocusProvider) =>
        this.reactRoot?.render(this.BlockNoteReactContainer(hocuspocusProvider))
      );
    } else {
      this.reactRoot.render(this.BlockNoteReactContainer());
    }
  }

  disconnectedCallback() {
    if (this.reactRoot) {
      this.reactRoot.unmount();
      this.reactRoot = null;
    }

    if (this.stimulusApplication) {
      this.stimulusApplication.stop();
      this.stimulusApplication = null;
    }
  }

  private BlockNoteReactContainer = (hocuspocusProvider?:HocuspocusProvider) => {
    return React.createElement(
      ShadowDomWrapper,
      { target: this.mount },
      React.createElement(
        OpBlockNoteContainer,
        {
          inputField: document.createElement('input'),
          activeUser: this.parseActiveUser()!,
          readOnly: this.getAttribute('read-only') === 'true',
          openProjectUrl: this.getAttribute('open-project-url') ?? '',
          attachmentsUploadUrl: this.getAttribute('attachments-upload-url') ?? '',
          attachmentsCollectionKey: this.getAttribute('attachments-collection-key') ?? '',
          hocuspocusProvider: hocuspocusProvider,
          errorContainer: this.stimulusMount,
        }
      )
    );
  };

  private parseActiveUser():User | null {
    const userData = this.getAttribute('active-user');
    if (userData) {
      try {
        return JSON.parse(userData) as User;
      } catch (e) {
        console.error('Failed to parse active user data:', e);
        return null;
      }
    }
    return null;
  }

}

if (!customElements.get('op-block-note')) {
  customElements.define('op-block-note', BlockNoteElement);
}

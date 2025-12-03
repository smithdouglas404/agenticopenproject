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

import { createRoot, Root } from 'react-dom/client';
import { css, html, LitElement, unsafeCSS } from 'lit';
import { customElement, property } from 'lit/decorators.js';
import { HocuspocusProvider } from '@hocuspocus/provider';
import { User } from '@blocknote/core/comments';
import OpBlockNoteContainer from '../react/OpBlockNoteContainer';
import React from 'react';
import mantineStylesRaw from '../../node_modules/@blocknote/mantine/src/style.css?raw';
import mantineStylesUrl from '@blocknote/mantine/style.css?url';
import { LiveCollaborationManager } from 'core-stimulus/helpers/live-collaboration-helpers';

@customElement('block-note')
export class BlockNoteElement extends LitElement {
  static styles = [css`${unsafeCSS(mantineStylesRaw)}`, css`
    :host
      display: block;
    `];

  private reactRoot:Root|null;

  @property({attribute: 'input-text'})
  inputText = '';

  @property({attribute: 'active-user', type: Object})
  activeUser:User;

  @property({type: Boolean, reflect: true})
  readonly = false;

  @property({attribute: 'openproject-url'})
  openProjectUrl = '';

  @property({attribute: 'attachments-upload-url'})
  attachmentsUploadUrl = '';

  @property({attribute: 'attachments-collection-key'})
  attachmentsCollectionKey = '';

  @property({attribute: 'collaboration-enabled', type: Boolean})
  collaborationEnabled  = false;

  blockNoteInputFieldTarget:HTMLInputElement;

  firstUpdated() {
    this.blockNoteInputFieldTarget = this.querySelector('[data-block-note-target="blockNoteInputField"]')!;
    this._mountReact();
  }

  updated() {
    this._mountReact();
  }

  _mountReact() {
    if (!this.reactRoot) {
      this.reactRoot = createRoot(this.shadowRoot!);
    }

    if (false) { // this.collaborationEnabled
      const root = this.reactRoot!;
      LiveCollaborationManager.onReady((hocuspocusProvider) => {
        root.render(this.BlockNoteReactContainer(hocuspocusProvider));
      });
    } else {
      this.reactRoot.render(this.BlockNoteReactContainer());
    }
  }

  render() {
    return html`
      <link rel="stylesheet" href="${mantineStylesUrl}">
    `;
  }

  BlockNoteReactContainer(hocuspocusProvider?:HocuspocusProvider) {
    return React.createElement(OpBlockNoteContainer, {
      inputField: this.blockNoteInputFieldTarget,
      inputText: this.inputText,
      activeUser: this.activeUser,
      readOnly: this.readonly,
      openProjectUrl: this.openProjectUrl,
      attachmentsUploadUrl: this.attachmentsUploadUrl,
      attachmentsCollectionKey: this.attachmentsCollectionKey,
      hocuspocusProvider: hocuspocusProvider,
    });
  }
}

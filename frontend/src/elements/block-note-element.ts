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
import { LiveCollaborationManager } from 'core-stimulus/helpers/live-collaboration-helpers';
import React from 'react';
import { createRoot } from 'react-dom/client';
import OpBlockNoteContainer from '../react/OpBlockNoteContainer';

// @ts-ignore - loading css
import mantineStyles from '@blocknote/mantine/style.css?url';

class BlockNoteElement extends HTMLElement {
  private mount:HTMLDivElement;

  constructor() {
    super();

    const shadowRoot = this.attachShadow({ mode: 'open' });
    this.mount = document.createElement('div');
    shadowRoot.appendChild(this.mount);

    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = mantineStyles;
    shadowRoot.appendChild(link);
  }

  connectedCallback() {
    const root = createRoot(this.mount);

    const collaborationEnabled = this.getAttribute('collaboration-enabled') === 'true';
    if (collaborationEnabled) {
      LiveCollaborationManager.onReady((hocuspocusProvider) => {
        root.render(this.BlockNoteReactContainer(hocuspocusProvider));
      });
    } else {
      root.render(this.BlockNoteReactContainer());
    }
  }

  BlockNoteReactContainer(hocuspocusProvider?:HocuspocusProvider) {
    return React.createElement(OpBlockNoteContainer, {
      activeUser: this.getAttribute('active-user') as unknown as User,
      readOnly: this.getAttribute('read-only') === 'true',
      openProjectUrl: this.getAttribute('open-project-url') || '',
      attachmentsUploadUrl: this.getAttribute('attachments-upload-url') || '',
      attachmentsCollectionKey: this.getAttribute('attachments-collection-key') || '',
      hocuspocusProvider: hocuspocusProvider,
    });
  }
}

customElements.define('op-block-note', BlockNoteElement);

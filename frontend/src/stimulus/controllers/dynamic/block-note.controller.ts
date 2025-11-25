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
import type { HocuspocusProvider } from '@hocuspocus/provider';
import { Controller } from '@hotwired/stimulus';
import { LiveCollaborationManager } from 'core-stimulus/helpers/live-collaboration-helpers';
import React from 'react';
import { createRoot } from 'react-dom/client';
import OpBlockNoteContainer from '../../../react/OpBlockNoteContainer';

export default class extends Controller {
  static targets = [
    'blockNoteEditor',
    'blockNoteInputField',
  ];

  declare readonly blockNoteEditorTarget:HTMLElement;
  declare readonly blockNoteInputFieldTarget:HTMLInputElement;

  static values = {
    inputText: String,
    activeUser: Object,
    openProjectUrl: String,
    attachmentsUploadUrl: String,
    attachmentsCollectionKey: String,

    collaborationEnabled: Boolean,
  };

  declare readonly inputTextValue:string;
  declare readonly activeUserValue:User;
  declare readonly openProjectUrlValue:string;
  declare readonly attachmentsUploadUrlValue:string;
  declare readonly attachmentsCollectionKeyValue:string;

  declare readonly collaborationEnabledValue:string;

  connect() {
    const root = createRoot(this.blockNoteEditorTarget);

    if (this.collaborationEnabledValue) {
      LiveCollaborationManager.onReady((hocuspocusProvider) => {
        root.render(this.BlockNoteReactContainer(hocuspocusProvider));
      });
    } else {
      root.render(this.BlockNoteReactContainer());
    }
  }

  BlockNoteReactContainer(hocuspocusProvider?:HocuspocusProvider) {
    return React.createElement(OpBlockNoteContainer, {
      inputField: this.blockNoteInputFieldTarget,
      inputText: this.inputTextValue,
      activeUser: this.activeUserValue,
      openProjectUrl: this.openProjectUrlValue,
      attachmentsUploadUrl: this.attachmentsUploadUrlValue,
      attachmentsCollectionKey: this.attachmentsCollectionKeyValue,
      hocuspocusProvider: hocuspocusProvider,
    });
  }
}

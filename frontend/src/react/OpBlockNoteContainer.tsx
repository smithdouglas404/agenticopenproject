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

import { User } from '@blocknote/core/comments';
import { HocuspocusProvider } from '@hocuspocus/provider';
import * as Y from 'yjs';
import { BlockNoteEditor } from './components/BlockNoteEditor';
import { useCollaboration } from './hooks/useCollaboration';

export interface OpBlockNoteContainerProps {
  inputField:HTMLInputElement;
  inputText?:string;
  activeUser:User;
  readOnly:boolean;
  openProjectUrl:string;
  attachmentsUploadUrl:string;
  attachmentsCollectionKey:string;
  hocuspocusProvider?:HocuspocusProvider;
}

export default function OpBlockNoteContainer({ inputField,
                                               inputText,
                                               activeUser,
                                               readOnly,
                                               openProjectUrl,
                                               attachmentsUploadUrl,
                                               attachmentsCollectionKey,
                                               hocuspocusProvider }:OpBlockNoteContainerProps) {
  let doc:Y.Doc;

  if(hocuspocusProvider) {
    doc = hocuspocusProvider.document;
  } else { // collaboration disabled (for test environments)
    doc = new Y.Doc();

    if (inputText) {
      try {
        const update = Uint8Array.from(atob(inputText), c => c.charCodeAt(0));
        Y.applyUpdate(doc, update);
      } catch (e) {
        console.error('Failed to load document binary', e);
        doc = new Y.Doc();
      }
    }
  }

  const { isLoading, connectionError } = useCollaboration(hocuspocusProvider, doc, inputField);

  if (isLoading) {
    return (
      <div>
        <div className={'mb-3'}>
          <div style={{ width: '25%', height: '40px' }} className={'SkeletonBox'} />
        </div>
        <div className={'mb-3'}>
          <div style={{ width: '100%', height: '150px' }} className={'SkeletonBox'} />
        </div>
      </div>
    );
  }

  if (connectionError) {
    return (
      <div
        id="documents-show-edit-view-connection-error-notice-component"
        data-controller="documents--connection-error-handler"
      />
    );
  }

  return (
    <BlockNoteEditor
      activeUser={activeUser}
      readOnly={readOnly}
      openProjectUrl={openProjectUrl}
      attachmentsUploadUrl={attachmentsUploadUrl}
      attachmentsCollectionKey={attachmentsCollectionKey}
      hocuspocusProvider={hocuspocusProvider}
      doc={doc}
    />
  );
}

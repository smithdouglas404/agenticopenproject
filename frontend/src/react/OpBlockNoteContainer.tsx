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

import { BlockNoteSchema, defaultBlockSpecs, filterSuggestionItems } from '@blocknote/core';
import { User } from '@blocknote/core/comments';
import { BlockNoteView } from '@blocknote/mantine';
import { getDefaultReactSlashMenuItems, SuggestionMenuController, useCreateBlockNote } from '@blocknote/react';
import { HocuspocusProvider } from '@hocuspocus/provider';
import { OpColorMode } from 'core-app/core/setup/globals/theme-utils';
import { getDefaultOpenProjectSlashMenuItems, initOpenProjectApi, openProjectWorkPackageBlockSpec } from 'op-blocknote-extensions';
import { useEffect, useState } from 'react';
import * as Y from 'yjs';

export interface OpBlockNoteContainerProps {
  inputField:HTMLInputElement;
  inputText?:string;
  hocuspocusUrl:string;
  hocuspocusAccessToken:string;
  users:User[];
  activeUser:User;
  documentName:string;
  documentId:string;
  openProjectUrl:string;
}

const schema = BlockNoteSchema.create({
  blockSpecs: {
    ...defaultBlockSpecs,
    openProjectWorkPackage: openProjectWorkPackageBlockSpec(),
  },
});

const detectTheme = ():OpColorMode => { return window.OpenProject.theme.detectOpColorMode(); };

export default function OpBlockNoteContainer({ inputField,
                                               inputText,
                                               hocuspocusUrl,
                                               hocuspocusAccessToken,
                                               users,
                                               activeUser,
                                               documentName,
                                               openProjectUrl }:OpBlockNoteContainerProps) {
  const [isLoading, setIsLoading] = useState(true);

  initOpenProjectApi({ baseUrl: openProjectUrl});

  let doc = new Y.Doc();

  const collaborationEnabled = Boolean(hocuspocusUrl && documentName && hocuspocusAccessToken && activeUser);
  let hocuspocusProvider:HocuspocusProvider | null = null;

  let editorParams:any;
  if(collaborationEnabled) {
    hocuspocusProvider = new HocuspocusProvider({
      url: hocuspocusUrl,
      name: documentName,
      token: hocuspocusAccessToken,
      document: doc
    });

    editorParams = {
      schema,
      resolveUsers: async (userIds:string[]) => users.filter((user) => userIds.includes(user.id)),
      collaboration: {
        provider: hocuspocusProvider,
        fragment: doc.getXmlFragment('document-store'),
        user: {
          name: activeUser.username,
          color: '#' + Math.floor(Math.random() * 16777215).toString(16).padStart(6, '0'),
        },
        showCursorLabels: 'activity'
      },
    };
  } else { // collaboration disabled
    if (inputText) {
      try {
        const update = Uint8Array.from(atob(inputText), c => c.charCodeAt(0));
        Y.applyUpdate(doc, update);
      } catch (e) {
        console.error('Failed to load document binary', e);
        doc = new Y.Doc();
      }
    }

    editorParams = {
      schema,
      collaboration: {
        fragment: doc.getXmlFragment('document-store'),
      },
    };
  }

  const editor = useCreateBlockNote(editorParams, [activeUser]);
  type EditorType = typeof editor;

  const getCustomSlashMenuItems = (editor:EditorType) => {
    return [
      ...getDefaultReactSlashMenuItems(editor),
      ...getDefaultOpenProjectSlashMenuItems(editor),
    ];
  };

  useEffect(() => {
    async function prepareEditor() {
      if(collaborationEnabled && hocuspocusProvider) {
        hocuspocusProvider.on('synced', async () => {
          console.log('BlockNote collaboration synced');
          setIsLoading(false);
        });
        hocuspocusProvider.on('disconnect', () => {
          console.error('BlockNote collaboration disconnected');
          setIsLoading(true);
        });
      } else {
        doc.on('update', () => {
          const update = Y.encodeStateAsUpdate(doc);
          const b64 = btoa(String.fromCharCode(...update));
          inputField.value = b64;
        });
        setIsLoading(false);
      }
    }
    prepareEditor();
    return () => {
      if (hocuspocusProvider) {
        hocuspocusProvider.destroy();
      }
    };
  }, []);

  return (
    <>
      {isLoading ? <div>Loading...</div>
        :
        <BlockNoteView
          editor={editor}
          theme={detectTheme()}
          className={'block-note-editor-container'}
        >
          <SuggestionMenuController
            triggerCharacter="/"
            getItems={async (query:string) => filterSuggestionItems(getCustomSlashMenuItems(editor), query)}
          />
        </BlockNoteView>
      }
    </>
  );
}

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

import { BlockNoteEditorOptions, BlockNoteSchema, defaultBlockSpecs, filterSuggestionItems } from '@blocknote/core';
import { User } from '@blocknote/core/comments';
import { BlockNoteView } from '@blocknote/mantine';
import { getDefaultReactSlashMenuItems, SuggestionMenuController, useCreateBlockNote } from '@blocknote/react';
import { HocuspocusProvider } from '@hocuspocus/provider';
import { OpColorMode } from 'core-app/core/setup/globals/theme-utils';
import { getDefaultOpenProjectSlashMenuItems, initOpenProjectApi, openProjectWorkPackageBlockSpec } from 'op-blocknote-extensions';
import { useEffect, useState } from 'react';
import * as Y from 'yjs';
import { IUploadFile } from 'core-app/core/upload/upload.service';

export interface OpBlockNoteContainerProps {
  inputField:HTMLInputElement;
  inputText?:string;
  hocuspocusUrl:string;
  oauthToken:string,
  activeUser:User;
  documentName:string;
  documentId:string;
  openProjectUrl:string;
  attachmentsUploadUrl:string;
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
                                               oauthToken,
                                               activeUser,
                                               documentName,
                                               documentId,
                                               openProjectUrl,
                                               attachmentsUploadUrl }:OpBlockNoteContainerProps) {
  const [isLoading, setIsLoading] = useState(true);

  initOpenProjectApi({ baseUrl: openProjectUrl });

  let doc = new Y.Doc();

  const collaborationEnabled = Boolean(hocuspocusUrl && documentName && oauthToken && activeUser);
  let hocuspocusProvider:HocuspocusProvider | null = null;

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let editorParams:Partial<BlockNoteEditorOptions<any, any, any>>;
  if(collaborationEnabled) {
    const url = new URL(hocuspocusUrl);
    url.searchParams.set('document_id', documentId);
    url.searchParams.set('openproject_base_path', openProjectUrl);

    hocuspocusProvider = new HocuspocusProvider({
      url: url.toString(),
      name: documentName,
      token: oauthToken,
      document: doc
    });

    editorParams = {
      schema,
      collaboration: {
        provider: hocuspocusProvider,
        fragment: doc.getXmlFragment('document-store'),
        user: {
          name: activeUser.username,
          color: '#' + Math.floor(Math.random() * 16777215).toString(16).padStart(6, '0'),
        },
        showCursorLabels: 'activity'
      },
      uploadFile,
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
        provider: null,
        fragment: doc.getXmlFragment('document-store'),
        user: {
          name: activeUser.username,
          color: '#333333',
        },
      },
      uploadFile,
    };
  }

  const editor = useCreateBlockNote(editorParams, [activeUser]);
  type EditorType = typeof editor;

  const fileToIUploadFile = (file:File):IUploadFile => ({
    file: file
  });

  async function uploadFile(file:File) {
    const pluginContext = await window.OpenProject.getPluginContext();
    try {
      const service = pluginContext.services.attachmentsResourceService;
      const iUploadFile = fileToIUploadFile(file);
      const result = await service.addAttachments('documents', attachmentsUploadUrl, [iUploadFile]).toPromise();

      return result?.[0]._links.downloadLocation.href ?? '';
    } catch(error:any) {
      const toastService = pluginContext.services.notifications;
      toastService.addError(error);

      return '';
    }
  }

  const getCustomSlashMenuItems = (editor:EditorType) => {
    // eslint-disable-next-line @typescript-eslint/no-unsafe-return
    return [
      ...getDefaultReactSlashMenuItems(editor),
      // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
      ...getDefaultOpenProjectSlashMenuItems(editor),
    ];
  };

  useEffect(() => {
    const updateInput = () => {
      const update = Y.encodeStateAsUpdate(doc);
      const b64 = btoa(String.fromCharCode(...update));
      inputField.value = b64;
    };

    if(collaborationEnabled && hocuspocusProvider) {
      hocuspocusProvider.on('synced', () => setIsLoading(false));
      hocuspocusProvider.on('disconnect', () => setIsLoading(true));
    } else {
      doc.on('update', updateInput);
      setIsLoading(false);
    }

    return () => {
      if (collaborationEnabled && hocuspocusProvider) {
        hocuspocusProvider.destroy();
      } else {
        // disable Yjs update listener. Opposite of doc.on('update', ...);
        doc.off('update', updateInput);
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
            getItems={async (query:string) => Promise.resolve(filterSuggestionItems(getCustomSlashMenuItems(editor), query))}
          />
        </BlockNoteView>
      }
    </>
  );
}

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

import { BlockNoteEditorOptions, BlockNoteSchema, filterSuggestionItems } from '@blocknote/core';
import { User } from '@blocknote/core/comments';
import { BlockNoteView } from '@blocknote/mantine';
import { getDefaultReactSlashMenuItems, SuggestionMenuController, useCreateBlockNote } from '@blocknote/react';
import { HocuspocusProvider } from '@hocuspocus/provider';
import { IUploadFile } from 'core-app/core/upload/upload.service';
import { initializeOpBlockNoteExtensions, openProjectWorkPackageBlockSpec, openProjectWorkPackageSlashMenu } from 'op-blocknote-extensions';
import { firstValueFrom } from 'rxjs';
import * as Y from 'yjs';
import { BlockNoteLocaleResult, useBlockNoteLocale } from '../hooks/useBlockNoteLocale';
import { useOpTheme } from '../hooks/useOpTheme';

interface CollaborativeUser {
  name:string;
  color:string;
}

export interface BlockNoteEditorProps {
  activeUser:User;
  readOnly:boolean;
  openProjectUrl:string;
  attachmentsUploadUrl:string;
  attachmentsCollectionKey:string;
  hocuspocusProvider?:HocuspocusProvider;
  doc:Y.Doc;
}

const schema = BlockNoteSchema.create().extend({
  blockSpecs: {
    openProjectWorkPackage: openProjectWorkPackageBlockSpec(),
  },
});

export function BlockNoteEditor({
  activeUser,
  readOnly,
  openProjectUrl,
  attachmentsUploadUrl,
  attachmentsCollectionKey,
  hocuspocusProvider,
  doc,
}:BlockNoteEditorProps) {
  const { localeString, localeDictionary }:BlockNoteLocaleResult = useBlockNoteLocale(window.I18n.locale);
  initializeOpBlockNoteExtensions({ baseUrl: openProjectUrl, locale: localeString });

  let editorParams:Partial<BlockNoteEditorOptions<typeof schema.blockSchema, typeof schema.inlineContentSchema, typeof schema.styleSchema>>;

  if(hocuspocusProvider) {
    editorParams = {
      schema,
      collaboration: {
        provider: hocuspocusProvider,
        fragment: doc.getXmlFragment('document-store'),
        user: {
          id: activeUser.id,
          name: activeUser.username,
          color: '#' + Math.floor(Math.random() * 16777215).toString(16).padStart(6, '0'),
        } as unknown as CollaborativeUser,
        showCursorLabels: 'activity'
      },
      dictionary: localeDictionary,
      ...(isReadyForAttachmentUpload() && { uploadFile }),
    };
  } else {
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
      dictionary: localeDictionary,
      ...(isReadyForAttachmentUpload() && { uploadFile }),
    };
  }

  const editor = useCreateBlockNote(editorParams, [activeUser]);
  type EditorType = typeof editor;
  const theme = useOpTheme();

  function isReadyForAttachmentUpload():boolean {
    return (
      attachmentsCollectionKey !== undefined &&
      attachmentsCollectionKey !== '' &&
      attachmentsUploadUrl !== undefined &&
      attachmentsUploadUrl !== ''
    );
  }

  const fileToIUploadFile = (file:File):IUploadFile => ({
    file: file
  });

  async function uploadFile(file:File) {
    const pluginContext = await window.OpenProject.getPluginContext();
    try {
      const service = pluginContext.services.attachmentsResourceService;
      const iUploadFile = fileToIUploadFile(file);
      const result = await firstValueFrom(
        service.addAttachments(attachmentsCollectionKey, attachmentsUploadUrl, [iUploadFile])
      );

      return result?.[0]._links.staticDownloadLocation.href ?? '';
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
    } catch(error:any) {
      const toastService = pluginContext.services.notifications;
      // eslint-disable-next-line @typescript-eslint/no-unsafe-argument
      toastService.addError(error);

      return '';
    }
  }

  const getCustomSlashMenuItems = (editor:EditorType) => {
    return [
      ...getDefaultReactSlashMenuItems(editor),
      openProjectWorkPackageSlashMenu(editor),
    ];
  };

  return (
    <>
      <BlockNoteView
        editor={editor}
        slashMenu={false}
        theme={theme}
        editable={!readOnly}
        className={'block-note-editor-container'}
      >
        <SuggestionMenuController
          triggerCharacter="/"
          getItems={async (query:string) => Promise.resolve(filterSuggestionItems(getCustomSlashMenuItems(editor), query))}
        />
      </BlockNoteView>
    </>
  );
}

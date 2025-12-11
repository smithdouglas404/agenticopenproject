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
import { initializeOpBlockNoteExtensions, openProjectWorkPackageBlockSpec, openProjectWorkPackageSlashMenu } from 'op-blocknote-extensions';
import * as Y from 'yjs';
import { useEffect, useMemo } from 'react';
import { useBlockNoteAttachments } from '../hooks/useBlockNoteAttachments';
import { useBlockNoteLocale } from '../hooks/useBlockNoteLocale';
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

// Helper function to generate deterministic color from user ID
function generateUserColor(userId:string):string {
  let hash = 0;
  for (let i = 0; i < userId.length; i++) {
    hash = userId.charCodeAt(i) + ((hash << 5) - hash);
  }
  const color = Math.abs(hash) % 16777215;
  return '#' + color.toString(16).padStart(6, '0');
}

export function BlockNoteEditor({
  activeUser,
  readOnly,
  openProjectUrl,
  attachmentsUploadUrl,
  attachmentsCollectionKey,
  hocuspocusProvider,
  doc,
}:BlockNoteEditorProps) {
  const { localeString, localeDictionary } = useBlockNoteLocale(window.I18n.locale);
  const { enabled: attachmentsEnabled, uploadFile } = useBlockNoteAttachments(attachmentsCollectionKey, attachmentsUploadUrl);

  // Initialize extensions once on mount or when dependencies change
  useEffect(() => {
    initializeOpBlockNoteExtensions({ baseUrl: openProjectUrl, locale: localeString });
  }, [openProjectUrl, localeString]);

  // Memoize editor parameters to avoid recreation on every render
  const editorParams = useMemo<Partial<BlockNoteEditorOptions<typeof schema.blockSchema, typeof schema.inlineContentSchema, typeof schema.styleSchema>>>(() => {
    if (hocuspocusProvider) {
      return {
        schema,
        collaboration: {
          provider: hocuspocusProvider,
          fragment: doc.getXmlFragment('document-store'),
          user: {
            id: activeUser.id,
            name: activeUser.username,
            color: generateUserColor(activeUser.id),
          } as unknown as CollaborativeUser,
          showCursorLabels: 'activity'
        },
        dictionary: localeDictionary,
        ...(attachmentsEnabled && { uploadFile }),
      };
    } else {
      return {
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
        ...(attachmentsEnabled && { uploadFile }),
      };
    }
  }, [hocuspocusProvider, doc, activeUser, localeDictionary, attachmentsEnabled, uploadFile]);

  const editor = useCreateBlockNote(editorParams, [activeUser]);
  type EditorType = typeof editor;
  const theme = useOpTheme();

  // Memoize slash menu items to avoid recreation on every render
  const getCustomSlashMenuItems = useMemo(() => {
    return (editorInstance:EditorType) => [
      ...getDefaultReactSlashMenuItems(editorInstance),
      openProjectWorkPackageSlashMenu(editorInstance),
    ];
  }, []);

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

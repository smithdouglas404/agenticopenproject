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
import { DocumentLoadingSkeleton } from './components/DocumentLoadingSkeleton';
import { OpBlockNoteEditor } from './components/OpBlockNoteEditor';
import { useCollaboration } from './hooks/useCollaboration';
import { Banner, BaseStyles, ThemeProvider } from '@primer/react';
import { I18nProvider, useI18n } from './hooks/useI18n';
import { useEffect, useRef, useState } from 'react';

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

export default function OpBlockNoteContainer(props:OpBlockNoteContainerProps) {
  return (
    <ThemeProvider>
      <BaseStyles>
        <I18nProvider>
          <OpBlockNoteInnerContainer {...props} />
        </I18nProvider>
      </BaseStyles>
    </ThemeProvider>
  );
}

export function OpBlockNoteInnerContainer({
  inputField,
  inputText,
  activeUser,
  readOnly,
  openProjectUrl,
  attachmentsUploadUrl,
  attachmentsCollectionKey,
  hocuspocusProvider,
}:OpBlockNoteContainerProps) {

  const doc:Y.Doc = hocuspocusProvider
    ? hocuspocusProvider.document
    : (() => {
      // NOTE: This should only be used in TEST environments where there is no provider.
      const newDoc = new Y.Doc();
      if (inputText) {
        try {
          const update = Uint8Array.from(atob(inputText), c => c.charCodeAt(0));
          Y.applyUpdate(newDoc, update);
        } catch (e) {
          console.error('Failed to load document binary', e);
          return new Y.Doc();
        }
      }
      return newDoc;
    })();

  const { isLoading, connectionError } = useCollaboration(hocuspocusProvider, doc, inputField);
  const hadErrorRef = useRef(false);
  const [showRecoveryBanner, setShowRecoveryBanner] = useState(false);

  // Fetch error/recovery template based on connection state
  useEffect(() => {
    if (connectionError) {
      hadErrorRef.current = true;
    } else if (hadErrorRef.current) {
      // We've recovered from an error
      setShowRecoveryBanner(true);
      hadErrorRef.current = false;
    }
  }, [connectionError]);

  const { t } = useI18n();

  if (isLoading) {
    return <DocumentLoadingSkeleton />;
  }

  if (connectionError) {
    return (
      <Banner
        variant="critical"
        aria-label={t('js.documents.show_edit_view.connection_error_notice.title')}
        title={t('js.documents.show_edit_view.connection_error_notice.title')}
        description={t('js.documents.show_edit_view.connection_error_notice.description')}
        primaryAction={
          <Banner.PrimaryAction
            onClick={() => {
              window.location.reload();
            }}
          >
            {t('js.documents.show_edit_view.connection_error_notice.action')}
          </Banner.PrimaryAction>
        }
      />
    );
  }

  return (
    <>
      {showRecoveryBanner && (
        <Banner
          variant="success"
          aria-label={t('js.documents.show_edit_view.connection_recovery_notice.title')}
          title={t('js.documents.show_edit_view.connection_recovery_notice.title')}
          description={t('js.documents.show_edit_view.connection_recovery_notice.description')}
          onDismiss={() => setShowRecoveryBanner(false)}
        />
      )}
      <OpBlockNoteEditor
        activeUser={activeUser}
        readOnly={readOnly}
        openProjectUrl={openProjectUrl}
        attachmentsUploadUrl={attachmentsUploadUrl}
        attachmentsCollectionKey={attachmentsCollectionKey}
        hocuspocusProvider={hocuspocusProvider}
        doc={doc}
      />
    </>
  );
}


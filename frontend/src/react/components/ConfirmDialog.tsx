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

import { ConfirmationDialog, ConfirmationDialogProps } from '@primer/react';
import { useI18n } from '../hooks/useI18n';

type ConfirmButtonType = ConfirmationDialogProps['confirmButtonType'];
export type ConfirmDialogScheme = ConfirmButtonType;
export interface ConfirmDialogProps {
  scheme?:ConfirmDialogScheme;
  message:string;
  onClose:(gesture:'confirm' | 'close-button' | 'cancel' | 'escape') => void;
}

export function ConfirmDialog({ message, onClose, scheme = 'primary' }:ConfirmDialogProps) {
  const { t } = useI18n();

  return (
    <ConfirmationDialog
      title={t('js.modals.form_submit.title')}
      onClose={onClose}
      confirmButtonContent={t('js.button_continue')}
      cancelButtonContent={t('js.button_cancel')}
      confirmButtonType={scheme}
      className='ConfirmDialog'
    >
      {message}
    </ConfirmationDialog>
  );
}

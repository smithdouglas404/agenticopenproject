//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

/* eslint-disable @angular-eslint/component-selector */

import { ChangeDetectionStrategy, Component, CUSTOM_ELEMENTS_SCHEMA, inject, input, output } from '@angular/core';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { IconModule } from 'core-app/shared/components/icon/icon.module';
import { ErrorBlankSlateComponent } from '../error-blankslate/error-blankslate.component';

@Component({
  selector: 'widget-turbo-frame',
  templateUrl: './widget-turbo-frame.component.html',
  styleUrls: ['./widget-turbo-frame.component.sass'],
  imports: [ErrorBlankSlateComponent, IconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  schemas: [CUSTOM_ELEMENTS_SCHEMA]
})
export class WidgetTurboFrameComponent {
  readonly i18n = inject(I18nService);

  readonly id = input<string>();
  readonly src = input<string>();
  readonly name = input<string>();
  readonly errorAction = output<void>();

  readonly text = { not_available: this.i18n.t('js.grid.widgets.not_available') };
}

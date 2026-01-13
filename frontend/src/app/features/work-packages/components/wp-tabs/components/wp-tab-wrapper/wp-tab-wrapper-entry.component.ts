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

import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  Input,
} from '@angular/core';
import { populateInputsFromDataset } from 'core-app/shared/components/dataset-inputs';
import { WorkPackageIsolatedQuerySpaceDirective } from 'core-app/features/work-packages/directives/query-space/wp-isolated-query-space.directive';
import { WpSingleViewService } from 'core-app/features/work-packages/routing/wp-view-base/state/wp-single-view.service';

/**
 * An entry component to be rendered by Rails which shows the content of an individual WP tab
 */
@Component({
  hostDirectives: [WorkPackageIsolatedQuerySpaceDirective],
  standalone: false,
  template: `
    <op-wp-tab
      [workPackageId]="workPackageId"
      [tabIdentifier]="activeTab"
    ></op-wp-tab>

    <div class="work-packages-full-view--resizer hidden-for-mobile hide-when-print">
      <wp-resizer [elementClass]="'full-view-page-layout--right'"
                  [variableName]="'--full-view-split-right-width'"
                  [localStorageKey]="'openProject-fullViewFlexBasis'" />
    </div>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [
    WpSingleViewService,
  ]
})
export class WpTabWrapperEntryComponent {
  @Input() workPackageId:string;
  @Input() activeTab:string;

  constructor(readonly elementRef:ElementRef) {
    populateInputsFromDataset(this);
    document.body.classList.add('router--work-packages-base');
  }
}

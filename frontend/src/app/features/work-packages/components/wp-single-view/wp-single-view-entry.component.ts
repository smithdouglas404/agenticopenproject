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
  ChangeDetectorRef,
  Component,
  ElementRef,
  Input,
} from '@angular/core';
import { populateInputsFromDataset } from 'core-app/shared/components/dataset-inputs';
import { WorkPackageResource } from 'core-app/features/hal/resources/work-package-resource';
import { ApiV3Service } from 'core-app/core/apiv3/api-v3.service';

/**
 * An entry component to be rendered by Rails which opens a single view of WP details
 */
@Component({
  standalone: false,
  template: `
    @if (workPackage) {
      <div edit-form
           [resource]="workPackage"
           class="work-packages--show-view">
        <wp-single-view [workPackage]="workPackage" />
      </div>
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class WorkPackageSingleViewEntryComponent {
  @Input() workPackageId:string;
  public workPackage:WorkPackageResource;

  constructor(
    readonly elementRef:ElementRef,
    readonly apiV3Service:ApiV3Service,
    readonly cdRef:ChangeDetectorRef,
  ) {
    populateInputsFromDataset(this);

    this
      .apiV3Service
      .work_packages
      .id(this.workPackageId)
      .requireAndStream()
      .subscribe((wp:WorkPackageResource) => {
        this.workPackage = wp;
        this.cdRef.detectChanges();
      });

    document.body.classList.add('router--work-packages-base');
  }

  /* TODO: MAKE THIS WORK
  // enable other parts of the application to trigger an immediate update
  // e.g. a stimulus controller
  // currently used by the new activities tab which does its own polling
  @HostListener('document:ian-update-immediate')
  triggerImmediateUpdate() {
    this.storeService.reload();
  }

  protected init() {
    if (this.workPackage.id) {
      this.recentItemsService.add(this.workPackageId);

      // Set Focused WP
      this.wpTableFocus.updateFocus(this.workPackageId);
    }
  }
  */
}

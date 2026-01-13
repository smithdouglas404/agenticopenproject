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
  HostListener,
  Injector,
  Input,
  OnInit,
} from '@angular/core';
import { StateService } from '@uirouter/core';
import { CurrentUserService } from 'core-app/core/current-user/current-user.service';
import { RecentItemsService } from 'core-app/core/recent-items.service';
import { ProjectResource } from 'core-app/features/hal/resources/project-resource';
import { WorkPackageResource } from 'core-app/features/hal/resources/work-package-resource';
import { HalResourceNotificationService } from 'core-app/features/hal/services/hal-resource-notification.service';
import { WpSingleViewService } from 'core-app/features/work-packages/routing/wp-view-base/state/wp-single-view.service';
import { WorkPackageViewSelectionService } from 'core-app/features/work-packages/routing/wp-view-base/view-services/wp-view-selection.service';
import { WorkPackageSingleViewBase } from 'core-app/features/work-packages/routing/wp-view-base/work-package-single-view.base';
import { WorkPackageNotificationService } from 'core-app/features/work-packages/services/notifications/work-package-notification.service';
import { Observable, of } from 'rxjs';

@Component({
  templateUrl: './wp-full-view-header.component.html',
  selector: 'op-wp-full-view-header',
  providers: [
    WpSingleViewService,
    { provide: HalResourceNotificationService, useExisting: WorkPackageNotificationService },
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class WorkPackagesFullViewHeaderComponent extends WorkPackageSingleViewBase implements OnInit {
  // Watcher properties
  public isWatched:boolean;

  public displayReminderButton$:Observable<boolean> = of(false);

  public displayShareButton$:false|Observable<boolean> = false;

  public displayTimerButton = false;

  public displayWatchButton = false;

  public text = {
    fullView: {
      buttonMore: this.i18n.t('js.button_more'),
    },
  };

  constructor(
    public injector:Injector,
    public wpTableSelection:WorkPackageViewSelectionService,
    readonly $state:StateService,
    readonly currentUserService:CurrentUserService,
  ) {
    super(injector);
  }

  ngOnInit():void {
    this.observeWorkPackage();
  }

  protected init() {
    super.init();

    this.setWorkPackageScopeProperties(this.workPackage);
  }

  private setWorkPackageScopeProperties(wp:WorkPackageResource) {
    this.isWatched = Object.prototype.hasOwnProperty.call(wp, 'unwatch');
    this.displayWatchButton = Object.prototype.hasOwnProperty.call(wp, 'unwatch') || Object.prototype.hasOwnProperty.call(wp, 'watch');
    this.displayTimerButton = Object.prototype.hasOwnProperty.call(wp, 'logTime');
    this.displayShareButton$ = this.currentUserService.hasCapabilities$('work_package_shares/index', (wp.project as ProjectResource).id);
    this.displayReminderButton$ = this.currentUserService.isLoggedInAndHasCapabalities$(
      'work_packages/read',
      (this.workPackage.project as ProjectResource).id,
    );
  }
}

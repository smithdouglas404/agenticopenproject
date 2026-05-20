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

import { ChangeDetectionStrategy, Component } from '@angular/core';
import moment from 'moment-timezone';
import { EditFieldComponent } from 'core-app/shared/components/fields/edit/edit-field.component';
import { InjectField } from 'core-app/shared/helpers/angular/inject-field.decorator';
import { TimezoneService } from 'core-app/core/datetime/timezone.service';

@Component({
  template: `
    <input type="datetime-local"
           class="inline-edit--field op-input"
           [attr.aria-required]="required"
           [attr.required]="required"
           [disabled]="inFlight"
           [(ngModel)]="value"
           (keydown)="handler.handleUserKeydown($event)"
           [id]="handler.htmlId" />
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class DatetimeEditFieldComponent extends EditFieldComponent {
  @InjectField() readonly timezoneService:TimezoneService;

  public get value():string {
    const raw = this.resource[this.name] as string|null;
    if (!raw) return '';
    return this.timezoneService.parseDatetime(raw).format('YYYY-MM-DDTHH:mm');
  }

  public set value(inputVal:string) {
    this.resource[this.name] = this.parseValue(inputVal);
  }

  public parseValue(data:string):string|null {
    if (!moment(data, 'YYYY-MM-DDTHH:mm', true).isValid()) {
      return null;
    }
    const tz = this.timezoneService.userTimezone();
    return moment.tz(data, 'YYYY-MM-DDTHH:mm', tz).utc().format('YYYY-MM-DDTHH:mm:ss[Z]');
  }
}

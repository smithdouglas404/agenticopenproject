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

import { DisplayField } from 'core-app/shared/components/fields/display/display-field.module';
import { formatWorkPackageId } from 'core-app/shared/helpers/work-package-id-pattern';

export class WorkPackageDisplayField extends DisplayField {
  public text = {
    none: this.I18n.t('js.filter.noneElement'),
  };

  public get value() {
    return this.resource[this.name];
  }

  public get title() {
    if (this.isEmpty()) {
      return this.text.none;
    }
    return this.value.name;
  }

  public get wpId() {
    if (this.isEmpty()) {
      return null;
    }

    if (this.value.$loaded) {
      return this.value.id;
    }

    // Read WP ID from href
    return this.value.href.match(/(\d+)$/)[0];
  }

  /**
   * Returns the identifier for URL routing when the linked WP is loaded,
   * falling back to the numeric ID extracted from the href.
   *
   * Unlike `WorkPackageBaseResource.displayId`, this handles the case
   * where the related resource is only a HAL link (not yet fetched).
   */
  public get wpRoutingId():string {
    if (this.value?.$loaded && this.value.displayId) {
      // eslint-disable-next-line @typescript-eslint/no-unsafe-return,@typescript-eslint/no-unsafe-call
      return this.value.displayId.toString();
    }
    return this.wpId;
  }

  /**
   * Returns the work package ID formatted for display.
   *
   * Cannot delegate to `WorkPackageBaseResource.formattedId` because
   * the linked resource (`this.value`) may not be loaded — in that case
   * we fall back to extracting the numeric ID from the self-link href.
   */
  public get wpFormattedId():string {
    if (this.value?.$loaded && this.value.displayId) {
      return formatWorkPackageId(this.value.displayId.toString());
    }

    const id = this.wpId;
    if (!id) return '';

    return formatWorkPackageId(id);
  }

  public get valueString() {
    // cannot display the type name easily here as it may not be loaded
    return `${this.wpFormattedId} ${this.title}`;
  }

  public isEmpty():boolean {
    return !this.value;
  }

  public get unknownAttribute():boolean {
    return false;
  }
}

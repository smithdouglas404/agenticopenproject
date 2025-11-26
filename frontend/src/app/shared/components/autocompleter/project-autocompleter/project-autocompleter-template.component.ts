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
  TemplateRef,
  ViewChild,
  inject,
} from '@angular/core';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { IAutocompleterTemplateComponent } from 'core-app/shared/components/autocompleter/op-autocompleter/op-autocompleter.component';
import {
  toDOMString,
  projectRoadmapIconData,
  briefcaseIconData,
  SVGData,
} from '@openproject/octicons-angular';
import { IProjectAutocompleteItem } from './project-autocomplete-item';

@Component({
  templateUrl: './project-autocompleter-template.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class ProjectAutocompleterTemplateComponent implements IAutocompleterTemplateComponent {
  @ViewChild('optionTemplate') optionTemplate:TemplateRef<Element>;
  @ViewChild('labelTemplate') labelTemplate?:TemplateRef<Element>;

  readonly I18n = inject(I18nService);
  readonly sanitizer = inject(DomSanitizer);

  shouldShowWorkspaceTypeBadge(project:IProjectAutocompleteItem):boolean {
    return !!project._type && project._type !== 'Project';
  }

  workspaceTypeIconWithLabel(project:IProjectAutocompleteItem):SafeHtml {
    const workspaceType = project._type;
    if (!workspaceType) {
      return '';
    }

    const iconData = this.workspaceTypeSVGData(workspaceType);
    if (!iconData) {
      return '';
    }

    const htmlString = toDOMString(iconData, 'small', { 'aria-hidden': 'true', class: 'octicon' });
    const translatedTypeName = this.I18n.t(`js.include_workspaces.types.${workspaceType.toLowerCase()}`);
    const iconWithText = htmlString + ' ' + translatedTypeName;
    return this.sanitizer.bypassSecurityTrustHtml(iconWithText);
  }

  private workspaceTypeSVGData(workspaceType:string):SVGData|undefined {
    switch (workspaceType) {
      case 'Program': {
        return projectRoadmapIconData;
      }
      case 'Portfolio': {
        return briefcaseIconData;
      }
      default: {
        return undefined;
      }
    }
  }
}

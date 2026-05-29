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

import { HalResource } from 'core-app/features/hal/resources/hal-resource';
import { WorkPackageResource } from 'core-app/features/hal/resources/work-package-resource';
import { GlobalSearchInputComponent } from './global-search-input.component';

// followItem is verified through the prototype against a stand-in context, avoiding
// a real component instance whose many injected dependencies this branch never uses.
describe('GlobalSearchInputComponent#followItem', () => {
  let wpPathArgs:string[];
  let searchInScopeArgs:string[];
  let context:Pick<GlobalSearchInputComponent, 'wpPath'|'selectedItem'> & { searchInScope:(scope:string) => void };

  function callFollowItem(item:unknown):void {
    GlobalSearchInputComponent.prototype.followItem.call(context, item);
  }

  beforeEach(() => {
    wpPathArgs = [];
    searchInScopeArgs = [];
    context = {
      wpPath: (id:string):string => {
        wpPathArgs.push(id);
        // A fragment keeps followItem's window.location assignment from navigating the runner.
        return '#stub';
      },
      selectedItem: undefined,
      searchInScope: (scope:string):void => {
        searchInScopeArgs.push(scope);
      },
    };
  });

  describe('when item is a HalResource', () => {
    let item:WorkPackageResource;

    beforeEach(() => {
      item = Object.create(HalResource.prototype) as WorkPackageResource;
      Object.defineProperty(item, 'id', { get: () => '42', configurable: true });
      Object.defineProperty(item, 'displayId', { get: () => 'PROJ-42', configurable: true });
    });

    it('calls wpPath with displayId', () => {
      callFollowItem(item);
      expect(wpPathArgs).toEqual(['PROJ-42']);
    });

    it('does not call wpPath with the numeric id', () => {
      callFollowItem(item);
      expect(wpPathArgs).not.toContain('42');
    });

    it('sets selectedItem to the item', () => {
      callFollowItem(item);
      expect(context.selectedItem).toBe(item);
    });
  });

  describe('when item is a scope option (not a HalResource)', () => {
    it('delegates to searchInScope and does not call wpPath', () => {
      callFollowItem({ projectScope: 'current_project', text: 'In this project ↵' });
      expect(searchInScopeArgs).toEqual(['current_project']);
      expect(wpPathArgs).toEqual([]);
    });
  });

  describe('when item is undefined', () => {
    it('does nothing', () => {
      callFollowItem(undefined);
      expect(wpPathArgs).toEqual([]);
      expect(searchInScopeArgs).toEqual([]);
    });
  });
});

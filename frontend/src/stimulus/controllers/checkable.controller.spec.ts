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
/* eslint-disable @typescript-eslint/no-empty-function, @typescript-eslint/no-explicit-any, @typescript-eslint/no-unsafe-assignment */

import CheckableController from './checkable.controller';

describe('CheckableController', () => {
  let controller:any;
  let inputs:HTMLInputElement[];

  beforeEach(() => {
    // Create a plain object that uses the controller prototype so we can call methods
    controller = Object.create(CheckableController.prototype);

    inputs = [0, 1, 2].map(() => {
      const input = document.createElement('input');
      input.type = 'checkbox';
      input.checked = false;
      return input;
    });

    controller.checkboxTargets = inputs;
  });

  it('checks all when none are checked', () => {
    controller.toggleAll(new Event('click'));

    expect(inputs.every((i) => i.checked)).toBeTrue();
  });

  it('checks all when some are checked (mixed state)', () => {
    inputs[0].checked = true; // mixed

    controller.toggleAll(new Event('click'));

    expect(inputs.every((i) => i.checked)).toBeTrue();
  });

  it('unchecks all when all are checked', () => {
    inputs.forEach((i) => (i.checked = true));

    controller.toggleAll(new Event('click'));

    expect(inputs.every((i) => !i.checked)).toBeTrue();
  });

  it('dispatches input event', () => {
    const dispatchSpy = spyOn(inputs[0], 'dispatchEvent').and.callThrough();

    controller.toggleAll(new Event('click'));

    expect(dispatchSpy).toHaveBeenCalledTimes(1);

    const eventArg = dispatchSpy.calls.mostRecent().args[0];

    expect(eventArg.type).toBe('input');
    expect(eventArg.bubbles).toBe(false);
    expect(eventArg.cancelable).toBe(true);
  });

  it('checkAll calls toggleChecked(true)', () => {
    spyOn(controller, 'toggleChecked').and.callFake(() => {});

    controller.checkAll(new Event('click'));

    expect(controller.toggleChecked).toHaveBeenCalledWith(controller.checkboxTargets, true);
  });

  it('uncheckAll calls toggleChecked(false)', () => {
    spyOn(controller, 'toggleChecked').and.callFake(() => {});

    controller.uncheckAll(new Event('click'));

    expect(controller.toggleChecked).toHaveBeenCalledWith(controller.checkboxTargets, false);
  });
});

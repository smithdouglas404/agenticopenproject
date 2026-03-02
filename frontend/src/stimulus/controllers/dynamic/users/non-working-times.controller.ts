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

import { Controller } from '@hotwired/stimulus';
import { Calendar } from '@fullcalendar/core';
import multiMonthPlugin from '@fullcalendar/multimonth';
import allLocales from '@fullcalendar/core/locales-all';

interface NonWorkingDayEvent {
  date?:string;
  start?:string;
  end?:string;
  title:string;
  type:'global' | 'user';
}

export default class UsersNonWorkingDaysController extends Controller {
  static targets = ['calendar'];

  static values = {
    events: Array,
    year: Number,
    locale: String,
    startOfWeek: Number,
  };

  declare readonly calendarTarget:HTMLElement;
  declare readonly eventsValue:NonWorkingDayEvent[];
  declare readonly yearValue:number;
  declare readonly localeValue:string;
  declare readonly startOfWeekValue:number;

  private calendar:Calendar;

  connect() {
    this.calendar = new Calendar(this.calendarTarget, {
  plugins: [multiMonthPlugin],
  initialView: 'multiMonthYear',
  multiMonthMaxColumns: 1,
      locales: allLocales,
      locale: this.localeValue,
      firstDay: this.startOfWeekValue,
      initialDate: `${this.yearValue}-01-01`,
      headerToolbar: false,
      height: 'auto',
      events: this.buildEvents(),
    });

    this.calendar.render();

      // The stimulus controller gets initialized before the content wrapper is fully shown
      // so its height might not be set correctly yet.
      setTimeout(() => this.calendar.updateSize(), 25);
  }

  disconnect() {
    if (this.calendar) {
      this.calendar.destroy();
    }
  }

  private buildEvents() {
    return this.eventsValue.map((event) => {
      if (event.type === 'global') {
        return {
          date: event.date,
          title: event.title,
          display: 'background',
          classNames: ['non-working-day--global'],
        };
      }

      return {
        start: event.start,
        end: event.end,
        title: event.title,
        classNames: ['non-working-day--user'],
        allDay: true,
      };
    });
  }
}

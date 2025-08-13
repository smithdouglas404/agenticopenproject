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

import jQuery from 'jquery';
import 'jquery.cookie';

export interface RBGlobal {
  constants:{
    project_id:number
    sprint_id:number|null
  }
  i18n:{
    generating_graph:string
    burndown_graph:string
  }
  urlFor:(routeName:string, options?:{
    id?:string|number
    project_id?:string|number
    sprint_id?:string|number|null
  }) => string
}

declare global {
  interface Window {
    RB:RBGlobal
  }
}

declare const RB:RBGlobal;

export interface SaveDirectives {
  url:string;
  method:string;
  data:string;
}

export interface Editable {
  $:JQuery;
  displayEditor(editor:JQuery):void;
  getEditor():JQuery;
}

// Utilities
export class Dialog {
  static msg(msg:string) {
    let dialog;
    let baseClasses;

    baseClasses = 'ui-button ui-widget ui-state-default ui-corner-all';

    if ($('#msgBox').length === 0) {
      dialog = $('<div id="msgBox"></div>').appendTo('body');
    } else {
      dialog = $('#msgBox');
    }

    dialog.html(msg);
    dialog.dialog({
      title: 'Backlogs Plugin',
      buttons: [
        {
          text: 'OK',
          class: 'button -primary',
          click() {
            $(this).dialog('close');
          },
        }],
      modal: true,
    });
    $('.button').removeClass(baseClasses);
    $('.ui-icon-closethick').prop('title', 'close');
  }
}

// Abstract the user preference from the rest of the RB objects
// so that we can change the underlying implementation as needed
export class UserPreferences {
  static get(key:string) {
    return jQuery.cookie(key);
  }

  static set(key:string, value:any) {
    jQuery.cookie(key, value, { expires: 365 * 10 });
  }
}

import { Controller } from '@hotwired/stimulus';

import 'jquery.flot';
import 'jquery.flot/excanvas';

import 'core-vendor/jquery.jeditable.mini';
import 'core-vendor/jquery.colorcontrast';

import './backlogs/common';
import './backlogs/master_backlog';
import './backlogs/backlog';
import './backlogs/burndown';
import './backlogs/model';
import './backlogs/editable_inplace';
import './backlogs/sprint';
import './backlogs/work_package';
import './backlogs/story';
import './backlogs/task';
import './backlogs/impediment';
import './backlogs/taskboard';
import './backlogs/show_main';
import { createRoot, Root } from 'react-dom/client';
import React from 'react';
import BacklogsContainer from '../../../react/backlogs/BacklogsContainer';
import TaskboardContainer from '../../../react/backlogs/TaskboardContainer';

export default class BacklogsController extends Controller {

  connect(): void {
    let reactRoot:HTMLElement;
    if (document.getElementById("backlogs_container2")) {
      reactRoot = document.getElementById("backlogs_container2")!
      createRoot(reactRoot).render(React.createElement(BacklogsContainer, {}))
    } else {
      reactRoot = document.getElementById("taskboard2")!
      createRoot(reactRoot).render(React.createElement(TaskboardContainer, {}))
    }
  }
}

import { Controller } from '@hotwired/stimulus';

import 'core-vendor/jquery.jeditable.mini';
import 'core-vendor/jquery.colorcontrast';

import './backlogs/common';
import './backlogs/model';
import './backlogs/editable_inplace';
import './backlogs/sprint';
import './backlogs/work_package';
import './backlogs/story';
import './backlogs/task';
import './backlogs/impediment';
import './backlogs/taskboard';
import './backlogs/show_main';

export default class BacklogsController extends Controller {
}

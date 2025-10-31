import {
  ChangeDetectionStrategy,
  Component,
} from '@angular/core';
import { AbstractTurboWidgetComponent } from 'core-app/shared/components/grids/widgets/abstract-turbo-widget.component';

@Component({
  templateUrl: './members.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class WidgetMembersComponent extends AbstractTurboWidgetComponent {
  override frameId = 'grids-widgets-members';
  override name = 'members';
}

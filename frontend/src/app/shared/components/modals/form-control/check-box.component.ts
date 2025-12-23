import { ChangeDetectionStrategy, Component, forwardRef, input, signal } from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { PrimerFormControlBaseComponent } from './form-control.component';


@Component({
  selector: 'op-check-box',
  templateUrl: './check-box.component.html',
  providers: [
    {
      provide: NG_VALUE_ACCESSOR,
      useExisting: forwardRef(() => PrimerCheckBoxComponent),
      multi: true,
    }
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PrimerCheckBoxComponent extends PrimerFormControlBaseComponent {
  readonly value = signal<boolean|null>(false);

  writeValue(value:boolean | null):void {
    this.value.set(value);
  }
}

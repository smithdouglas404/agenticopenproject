import { booleanAttribute, ChangeDetectionStrategy, Component, CUSTOM_ELEMENTS_SCHEMA, forwardRef, input, signal } from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { PrimerFormControlBaseComponent } from './form-control.component';


@Component({
  selector: 'op-text-field',
  templateUrl: './text-field.component.html',
  providers: [
    {
      provide: NG_VALUE_ACCESSOR,
      useExisting: forwardRef(() => PrimerTextFieldComponent),
      multi: true,
    }
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  schemas: [CUSTOM_ELEMENTS_SCHEMA]
})
export class PrimerTextFieldComponent extends PrimerFormControlBaseComponent {
  readonly value = signal<string>('');

  writeValue(value:string | null):void {
    this.value.set(value ?? '');
  }

  onInput(event:Event):void {
    const next = (event.target as HTMLInputElement).value;
    this.value.set(next);
    this._onChange(next);
  }
}

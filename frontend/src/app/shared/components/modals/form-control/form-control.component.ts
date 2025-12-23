import { booleanAttribute, computed, Directive, input, signal } from '@angular/core';
import { ControlValueAccessor } from '@angular/forms';
import { generateId } from 'core-app/shared/helpers/dom-helpers';


@Directive()
export abstract class PrimerFormControlBaseComponent implements ControlValueAccessor {

  protected _onChange = (value:string) => {};
  private _onTouched = () => {};

  readonly inputId = input<string>();
  readonly name = input.required<string>();
  readonly label = input.required<string>();
  readonly caption = input<string>();
  readonly required = input(false, {transform: booleanAttribute});
  readonly disabled = signal(false);

  readonly id = computed(() => this.inputId() || generateId('field'));

  abstract writeValue(obj:any):void;

  registerOnChange(fn:(value:string) => void):void {
    this._onChange = fn;
  }

  registerOnTouched(fn:() => void):void {
    this._onTouched = fn;
  }

  setDisabledState(isDisabled:boolean):void {
    this.disabled.set(isDisabled);
  }

  onBlur():void {
    this._onTouched();
  }
}

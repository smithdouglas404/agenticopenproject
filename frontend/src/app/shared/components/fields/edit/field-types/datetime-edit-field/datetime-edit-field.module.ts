import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { DatetimeEditFieldComponent } from 'core-app/shared/components/fields/edit/field-types/datetime-edit-field/datetime-edit-field.component';
import { OpSharedModule } from 'core-app/shared/shared.module';

@NgModule({
  imports: [
    CommonModule,
    OpSharedModule,
  ],
  declarations: [
    DatetimeEditFieldComponent,
  ],
  exports: [
    DatetimeEditFieldComponent,
  ],
})
export class DatetimeEditFieldModule { }

import { Injector, NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { DisplayFieldService } from 'core-app/shared/components/fields/display/display-field.service';
import { DateTimeDisplayField } from 'core-app/shared/components/fields/display/field-types/datetime-display-field.module';
import { OpSharedModule } from 'core-app/shared/shared.module';
import { StatusTrackingAdditionalInfoComponent } from './components/additional-info/additional-info.component';
import { WorkPackageTabsService } from 'core-app/features/work-packages/components/wp-tabs/services/wp-tabs/wp-tabs.service';

export function initializeStatusTrackerField(injector: Injector) {
  const displayFieldService = injector.get(DisplayFieldService);

  displayFieldService.addFieldType(DateTimeDisplayField, 'datetime', ['startedAt', 'doneAt']);
}

@NgModule({
  imports: [
    CommonModule,
    OpSharedModule
  ],
  declarations: [StatusTrackingAdditionalInfoComponent],
  providers: [],
})
export class PluginModule {
  constructor(injector: Injector, wpTabsService: WorkPackageTabsService) {
    initializeStatusTrackerField(injector);

    wpTabsService.register({
      component: StatusTrackingAdditionalInfoComponent,
      name: 'Ticket Progress',
      id: 'status_tracking_additional_info',
    });
  }
}

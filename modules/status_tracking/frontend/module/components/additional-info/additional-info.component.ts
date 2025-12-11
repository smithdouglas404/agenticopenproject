import { Component, Injector, Input, OnInit } from '@angular/core';
import { WorkPackageResource } from 'core-app/features/hal/resources/work-package-resource';

@Component({
  selector: 'status-tracking-additional-info',
  template: `
    <div class="attributes-group">
      <div class="attributes-key-value">
        <div class="attributes-key-value--key">Started At</div>
        <div class="attributes-key-value--value-container">
        	<op-date-time *ngIf="workPackage.startedAt; else empty" [dateTimeValue]="workPackage.startedAt"></op-date-time>
        	<ng-template #empty>-</ng-template>
        </div>
      </div>
       <div class="attributes-key-value">
        <div class="attributes-key-value--key">Done At</div>
        <div class="attributes-key-value--value-container">
        	<op-date-time *ngIf="workPackage.doneAt; else empty" [dateTimeValue]="workPackage.doneAt"></op-date-time>
        	<ng-template #empty>-</ng-template>
        </div>
      </div>
    </div>
  `
})
export class StatusTrackingAdditionalInfoComponent implements OnInit {
  @Input() public workPackage: WorkPackageResource;

  constructor(public injector: Injector) {
  }

  ngOnInit() { }
}

import { EventEmitter, InjectionToken, Injector } from '@angular/core';
import { delegate } from '@knowledgecode/delegate';

export interface WorkPackageViewEventHandler<T> {
  /** Event name to register * */
  EVENT:string;

  /** Event context CSS selector */
  SELECTOR:string;

  /** Event callback handler */
  handleEvent(view:T, evt:Event):void;

  /** Event scope method */
  eventScope(view:T):HTMLElement;
}

export interface WorkPackageViewOutputs {
  // On selection updated
  selectionChanged:EventEmitter<string[]>;
  // On row (double) clicked
  itemClicked:EventEmitter<{ workPackageId:string, double:boolean }>;
  // On work package link / details icon clicked
  stateLinkClicked:EventEmitter<{ workPackageId:string, requestedState:string }>;
}

export const WorkPackageViewHandlerToken = new InjectionToken<WorkPackageViewEventHandler<any>>('CardEventHandler');

/**
 * Abstract view handler registry for globally handling arbitrary event on the
 * view container. Used e.g., for table to register single event callbacks for the entirety
 * of the table.
 */
export abstract class WorkPackageViewHandlerRegistry<T> {
  constructor(public readonly injector:Injector) {
  }

  protected abstract eventHandlers:((view:T) => WorkPackageViewEventHandler<T>)[];

  attachTo(viewRef:T) {
    this.eventHandlers.map((factory) => {
      const handler = factory(viewRef);
      const target = handler.eventScope(viewRef);

      delegate(target).on(handler.EVENT, handler.SELECTOR, (evt) => {
        handler.handleEvent(viewRef, evt.originalEvent);
      });

      return handler;
    });
  }
}

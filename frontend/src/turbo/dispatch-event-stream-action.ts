import { StreamActions, StreamElement } from '@hotwired/turbo';

const DISALLOWED_EVENT_NAMES = new Set(['submit']);

export function registerDispatchEventStreamActionGuard() {
  const originalDispatchEvent = StreamActions.dispatch_event;

  if (typeof originalDispatchEvent !== 'function') {
    return;
  }

  StreamActions.dispatch_event = function guardedDispatchEvent(this:StreamElement) {
    const eventName = this.getAttribute('name')?.trim().toLowerCase();

    if (eventName && DISALLOWED_EVENT_NAMES.has(eventName)) {
      console.warn(`[TurboPower] blocked disallowed event "${eventName}" for Turbo Streams operation "dispatch_event"`);
      return;
    }

    return originalDispatchEvent.call(this);
  };
}

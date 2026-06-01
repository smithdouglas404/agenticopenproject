import { StreamActions, StreamElement } from '@hotwired/turbo';
import TurboPower from 'turbo_power';
import { registerDispatchEventStreamActionGuard } from './dispatch-event-stream-action';

describe('dispatch_event stream action guard', () => {
  const originalDispatchEvent = StreamActions.dispatch_event;
  let unguardedDispatchEvent:(this:StreamElement) => void;

  beforeEach(() => {
    TurboPower.initialize(StreamActions);
    unguardedDispatchEvent = StreamActions.dispatch_event as (this:StreamElement) => void;
    registerDispatchEventStreamActionGuard();
  });

  afterEach(() => {
    StreamActions.dispatch_event = originalDispatchEvent;
  });

  function streamActionFor(name:string, target:Element, detail = '{}'):StreamElement {
    const template = document.createElement('template');
    template.content.appendChild(document.createTextNode(detail));

    return {
      getAttribute: (attributeName:string) => (attributeName === 'name' ? name : null),
      targetElements: [target],
      templateContent: template.content,
    } as unknown as StreamElement;
  }

  it('does not prevent submitting the form', () => {
    const form = document.createElement('form');
    let submitted = false;

    form.addEventListener('submit', () => {
      submitted = true;
    });

    unguardedDispatchEvent.call(streamActionFor('submit', form));

    expect(submitted).toBe(true);
  });

  it('blocks synthetic submit events', () => {
    const form = document.createElement('form');
    let submitted = false;
    vi.spyOn(console, 'warn').mockImplementation(() => undefined);

    form.addEventListener('submit', () => {
      submitted = true;
    });

    StreamActions.dispatch_event.call(streamActionFor(' Submit ', form));

    expect(submitted).toBe(false);
    expect(console.warn).toHaveBeenCalledWith(
      '[TurboPower] blocked disallowed event "submit" for Turbo Streams operation "dispatch_event"'
    );
  });

  it('allows non-disallowed events', () => {
    const target = document.createElement('div');
    let payload:unknown;

    target.addEventListener('openproject:test', (event) => {
      payload = (event as CustomEvent).detail;
    });

    StreamActions.dispatch_event.call(streamActionFor('openproject:test', target, '{"source":"spec"}'));

    expect(payload).toEqual({ source: 'spec' });
  });
});

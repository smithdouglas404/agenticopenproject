import { ApplicationController } from 'stimulus-use';
import { announce } from '@primer/live-region-element';

export const SUCCESS_AUTOHIDE_TIMEOUT = 5000;

export default class FlashController extends ApplicationController {
  static values = {
    autohide: Boolean,
  };

  static targets = [
    'item',
    'flash',
  ];

  declare autohideValue:boolean;
  declare readonly itemTargets:HTMLElement[];

  reloadPage() {
    window.location.reload();
  }

  itemTargetConnected(element:HTMLElement) {
    this.announceFlash(element);

    const autohide = element.dataset.autohide === 'true';
    if (this.autohideValue && autohide) {
      setTimeout(() => element.remove(), SUCCESS_AUTOHIDE_TIMEOUT);
    }
  }

  flashTargetDisconnected() {
    this.itemTargets.forEach((target:HTMLElement) => {
      if (target.innerHTML === '') {
        target.remove();
      }
    });
  }

  private announceFlash(element:HTMLElement) {
    const message = element.dataset.announcement?.trim();
    if (!message) return;

    const flashType = element.dataset.flashType;
    const politeness =
      flashType === 'error' || flashType === 'danger' ? 'assertive' : 'polite';

    void announce(message, { politeness });
  }
}

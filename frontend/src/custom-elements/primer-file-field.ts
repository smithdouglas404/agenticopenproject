import { controller, target } from '@github/catalyst';

@controller
class PrimerFileFieldElement extends HTMLElement {
  @target inputElement:HTMLInputElement;

  #abortController:AbortController | null;

  @target button:HTMLElement;
  @target label:HTMLElement;

  connectedCallback() {
    this.#abortController?.abort();
    const {signal} = (this.#abortController = new AbortController());

    this.inputElement.addEventListener('change', () => {
      const files = this.inputElement.files!;
      if (files.length === 0) {
        this.label.textContent = 'no file selected';
      } else {
        this.label.textContent = files[0].name;
      }
    }, { signal });
  }

  disconnectedCallback() {
    this.#abortController?.abort();
  }
}

// if (!window.customElements.get('primer-file-field')) {
//   window.PrimerFileFieldElement = PrimerFileFieldElement
//   window.customElements.define('primer-file-field', PrimerFileFieldElement)
// }

declare global {
  interface Window {
    PrimerFileFieldElement:typeof PrimerFileFieldElement
  }
}

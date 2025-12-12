import { css, LitElement, unsafeCSS } from 'lit';
import { customElement, property } from 'lit/decorators.js';
import { classMap } from 'lit/directives/class-map.js';
import { html, literal } from 'lit/static-html.js';

import buttonStyles from './../../node_modules/@openproject/primer-view-components/app/assets/styles/primer_view_components.css?raw';

export type ButtonSize = 'small' | 'medium' | 'large';
type Scheme = null | 'primary' | 'secondary' | 'default' | 'danger' | 'invisible' | 'link';
type AlignContent = 'center' | 'start';
type Tag = 'button' | 'a' | 'summary' | 'clipboard-copy';
type Type = 'button' | 'reset' | 'submit';

@customElement('primer-button')
export class PrimerButton extends LitElement {
  static styles = [ css`${unsafeCSS(buttonStyles)}`];

  @property() scheme:Scheme = null;
  @property() size:ButtonSize = 'medium';
  @property() block = false; // Whether button is full-width with `display: block`.
  @property() alignContent:AlignContent = 'center';
  @property() tag = literal`button`;
  @property() type:Type = 'button';
  @property() inactive = false;
  @property() disabled = false;
  @property() labelWrap = false;
  @property() value = '';

  @property() icon = '';

  @property() action = '';

  render() {
    const classes = {
      'btn-block': this.block,
      'Button--inactive': this.inactive,
      'Button--primary': this.scheme === 'primary',
      'Button--secondary': this.scheme === 'secondary' || this.scheme === 'default',
      'Button--danger': this.scheme == 'danger',
      'Button--invisible': this.scheme == 'invisible',
      'Button--link': this.scheme === 'link',
      'Button--small': this.size === 'small',
      'Button--medium': this.size === 'medium',
      'Button--large': this.size === 'large',
      'Button--fullWidth': this.block,
      'Button--labelWrap': this.labelWrap
    };

    return html`
      <${this.tag}
        type="${this.type}"
        class="Button ${classMap(classes)}"
        ?disabled=${this.disabled}
        value="${this.value}"
        data-action="${this.action}">
        <span class="Button-content">
          <span class="Button-label"><slot></slot></span>
        </span>
      </button>
    `;
  }
}

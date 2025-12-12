import { html, LitElement } from 'lit';
import { customElement, property } from 'lit/decorators.js';
import { classMap } from 'lit/directives/class-map.js';
import { ButtonSize } from './primer-button';

@customElement('primer-segmented-control-item')
export class PrimerSegmentedControlItem extends LitElement {
  @property({type: String}) label = '';
  @property({type: Boolean, reflect: true}) selected = false;
  @property() value = '';

  createRenderRoot() {
    // Render light DOM so parent can read attributes
    return this;
  }
}

// @customElement('primer-segmented-control-item')
// export class SegmentedControlItem extends LitElement {
//   static styles = [...PrimerSegmentedControl.styles];

//   @property() label = '';

//   @property() value = '';

//   @property({ type: Boolean, reflect: true })
//   selected = false;

//   // label: label,
//   // selected: selected,
//   // icon: icon,
//   // hide_labels: @hide_labels,
//   // size: @size,
//   // block: @full_width,

//   @property() icon = '';

//   @property({ type: Boolean })
//   hideLabels:false;

//   @property() size:ButtonSize = 'medium';

//   render() {
//     return html`
//       <li
//         class="SegmentedControl-item ${classMap({ 'SegmentedControl-item--selected': this.selected })}"
//         role="radio"
//         aria-checked="${this.selected}"
//         tabindex="${this.selected ? 0 : -1}"
//         @click="${this.select}">
//         ${
//           this.hideLabels
//             ? this.renderIconButton()
//             : this.renderButton()
//         }
//       </li>
//     `;
//   }

//   renderIconButton() {
//     return html`
//       <p style="color:red">Icon Buttons not supported yet.</p>
//     `;
//   }

//   renderButton() {
//     return html`
//       <primer-button
//         scheme="invisible"
//         size="${this.size}"
//         value="${this.value}"
//       >
//         ${this.label}
//       </primer-button>
//     `;
//   }

//   protected createRenderRoot() {
//     return this;
//   }

//   private select() {
//     this.dispatchEvent(
//       new CustomEvent('itemActivated', {
//         bubbles: true,
//         composed: true,
//         detail: { item: this, value: this.value },
//       })
//     );
//   }
// }

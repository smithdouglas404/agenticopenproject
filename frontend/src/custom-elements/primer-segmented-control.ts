

import { css, html, LitElement, unsafeCSS } from 'lit';
import { customElement, property, query, queryAssignedElements, state } from 'lit/decorators.js';
import { classMap } from 'lit/directives/class-map.js';
import { PrimerSegmentedControlItem } from './primer-segmented-control-item';

import segmentedControlStyles from './../../node_modules/@openproject/primer-view-components/app/components/primer/alpha/segmented_control.css?raw';
import { PrimerButton } from './primer-button';


type Size = 'small' | 'medium';
@customElement('primer-segmented-control')
export class PrimerSegmentedControl extends LitElement {
  static formAssociated = true;
  static styles = [ css`${unsafeCSS(segmentedControlStyles)}`];

  @property()
  hideLabels = false;

  @property()
  fullWidth = false;

  @property()
  size:Size = 'medium';

  @property()
  name = '';

  @state()
  private _dirty = false;

  private _internals:ElementInternals;

  get value():string {
    return this.selectedItem?.value ?? '';
  }

  set value(string) {
    this.items.forEach(i =>
      i.selected = (i.value === string)
    );
     this._updateFormValue();
  }

  get selectedIndex() {
    return this.selectedItem ? this.items.indexOf(this.selectedItem) : -1;
  }

  get selectedItem():PrimerSegmentedControlItem|undefined {
    return this._selectedListItems[0];
  }

  @queryAssignedElements({selector: 'primer-segmented-control-item'})
  items!:PrimerSegmentedControlItem[];

  @queryAssignedElements({selector: 'primer-segmented-control-item[selected]'})
  _selectedListItems!:PrimerSegmentedControlItem[];

@query('slot') slotElem!:HTMLSlotElement;

@query('segmented-control') control:HTMLElement;

protected firstUpdated() {
  this.slotElem.addEventListener('slotchange', () => {
    this.requestUpdate();
    //(this.control as any).connectedCallback();
    this._updateFormValue();
    (this.control as any).connectedCallback();
    console.log('TARGETING', ((this.control as any)));
    console.log('TARGETING', ((this.control as any).items));
  });

}

  constructor() {
    super();
    this._internals = this.attachInternals();
  }

  connectedCallback() {
    super.connectedCallback();
    this._updateFormValue();
  }

  checkValidity() {
    return this._internals.checkValidity();
  }


  formResetCallback() {
    this.items.forEach(i => i.selected = false);
    this._updateFormValue();
    this._dirty = false;
  }

  render() {
    const classes = {
      'SegmentedControl--small': this.size == 'small',
      'SegmentedControl--medium': this.size == 'medium',
      'SegmentedControl--iconOnly': this.hideLabels,
      'SegmentedControl--fullWidth': this.fullWidth
    };

    return html`
      <segmented-control>
        <ul 
          aria-label="${this.ariaLabel}" 
          role="list"
          class="SegmentedControl ${classMap(classes)}"
          >
          ${this.items.map((item, i) => html`
            <li 
              class="SegmentedControl-item ${item.selected ? 'SegmentedControl-item--selected' : ''}"
              role="listitem"
              data-targets="segmented-control.items">
              <button aria-current="${item.selected}" data-action="click:segmented-control#select">
                ${item.label}
              </button>
            </li>
          `)}
        </ul>
      </segmented-control>
      <slot></slot>
    `;
  }

  // @click=${() => this.handleSelect(i)}

  private _selectItem(selectedItem:PrimerSegmentedControlItem) {
    this.items.forEach((item) => {
      item.selected = item === selectedItem;
    });

    this._dirty = true;
    this._updateFormValue();
    this.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
    this.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
  }

  handleSelect(index:number) {
    this.items.forEach((item, i) => item.selected = (i === index));
    this.requestUpdate();
  }

  private _updateFormValue() {
    this._internals.setFormValue(this.value);
  }
}

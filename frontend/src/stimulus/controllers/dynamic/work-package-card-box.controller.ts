import { Controller } from '@hotwired/stimulus';

export default class WorkPackageCardBoxController extends Controller<HTMLElement> {
  static targets = ['item'];
  static values = {
    selectionGroup: String,
    sourceId: String,
  };

  static classes = ['selected'];

  declare readonly itemTargets:HTMLElement[];

  declare readonly selectionGroupValue:string;

  declare readonly sourceIdValue:string;

  declare readonly selectedClass:string;

  declare readonly hasSelectedClass:boolean;

  private static instances = new Set<WorkPackageCardBoxController>();
  private selectedItemIds = new Set<string>();
  private lastSelectedItemId:string|null = null;
  private abortController:AbortController|null = null;

  connect() {
    WorkPackageCardBoxController.instances.add(this);
    this.abortController = new AbortController();
    this.element.addEventListener('click', this.toggleSelection, {
      signal: this.abortController.signal,
      capture: true,
    });
  }

  disconnect() {
    WorkPackageCardBoxController.instances.delete(this);
    this.abortController?.abort();
    this.abortController = null;
  }

  toggleSelection = (event:MouseEvent) => {
    const item = this.findItem(event.target);
    if (!item) {
      return;
    }

    if (!this.shouldHandleSelection(event, item)) {
      return;
    }

    event.preventDefault();
    event.stopImmediatePropagation();

    this.clearPeerSelections();

    if (event.shiftKey && this.lastSelectedItemId) {
      this.selectRange(this.lastSelectedItemId, this.itemId(item));
    } else {
      this.toggleItem(item);
    }

    this.renderSelection();
    this.dispatchSelectionChange();
  };

  getSelectedItemIds():string[] {
    return this.itemTargets
      .map((item) => this.itemId(item))
      .filter((itemId) => this.selectedItemIds.has(itemId));
  }

  clearSelection() {
    this.selectedItemIds.clear();
    this.lastSelectedItemId = null;
    this.renderSelection();
    this.dispatchSelectionChange();
  }

  private shouldHandleSelection(event:MouseEvent, item:HTMLElement):boolean {
    return (
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      this.selectedItemIds.has(this.itemId(item))
    );
  }

  private toggleItem(item:HTMLElement) {
    const itemId = this.itemId(item);

    if (this.selectedItemIds.has(itemId)) {
      this.selectedItemIds.delete(itemId);
      if (this.lastSelectedItemId === itemId) {
        this.lastSelectedItemId = null;
      }
    } else {
      this.selectedItemIds.add(itemId);
      this.lastSelectedItemId = itemId;
    }
  }

  private selectRange(fromItemId:string, toItemId:string) {
    const itemIds = this.itemTargets.map((item) => this.itemId(item));
    const fromIndex = itemIds.indexOf(fromItemId);
    const toIndex = itemIds.indexOf(toItemId);

    if (fromIndex === -1 || toIndex === -1) {
      this.selectedItemIds.add(toItemId);
      this.lastSelectedItemId = toItemId;
      return;
    }

    const [start, end] = [fromIndex, toIndex].sort((a, b) => a - b);
    itemIds.slice(start, end + 1).forEach((itemId) => this.selectedItemIds.add(itemId));
    this.lastSelectedItemId = toItemId;
  }

  private clearPeerSelections() {
    WorkPackageCardBoxController.instances.forEach((controller) => {
      if (
        controller !== this &&
        controller.selectionGroupValue === this.selectionGroupValue &&
        controller.getSelectedItemIds().length > 0
      ) {
        controller.clearSelection();
      }
    });
  }

  private renderSelection() {
    this.itemTargets.forEach((item) => {
      const selected = this.selectedItemIds.has(this.itemId(item));

      item.classList.toggle(this.selectedClassName, selected);
      if (selected) {
        item.setAttribute('data-work-package-card-box-selected', 'true');
        item.setAttribute('aria-selected', 'true');
      } else {
        item.removeAttribute('data-work-package-card-box-selected');
        item.removeAttribute('aria-selected');
      }
    });
  }

  private dispatchSelectionChange() {
    this.dispatch('selection-change', {
      detail: {
        itemIds: this.getSelectedItemIds(),
        sourceId: this.sourceIdValue,
      },
      bubbles: true,
    });
  }

  private findItem(target:EventTarget|null):HTMLElement|null {
    if (!(target instanceof HTMLElement)) {
      return null;
    }

    return target.closest<HTMLElement>('[data-work-package-card-box-target~="item"]');
  }

  private itemId(item:HTMLElement):string {
    return item.dataset.workPackageCardBoxItemId ?? '';
  }

  private get selectedClassName() {
    return this.hasSelectedClass ? this.selectedClass : 'Box-card--multi-selected';
  }
}

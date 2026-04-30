import { Controller } from '@hotwired/stimulus';
import { combine } from '@atlaskit/pragmatic-drag-and-drop/combine';
import { CleanupFn } from '@atlaskit/pragmatic-drag-and-drop/dist/types/internal-types';
import { draggable, dropTargetForElements } from '@atlaskit/pragmatic-drag-and-drop/element/adapter';
import {
  attachClosestEdge,
  type Edge,
  extractClosestEdge,
} from '@atlaskit/pragmatic-drag-and-drop-hitbox/closest-edge';

import { itemData, isItemData, type ItemData } from './drag-and-drop';

type ItemState =
  | {
      type:'idle';
    }
  | {
      type:'preview';
      container:HTMLElement;
    }
  | {
      type:'is-dragging';
    }
  | {
      type:'is-dragging-over';
      closestEdge:Edge | null;
    };

const idle:ItemState = { type: 'idle' };

export default class ItemController extends Controller<HTMLElement> {
  static values = { itemId: String };

  declare itemIdValue:string;

  private state:ItemState = idle;
  private cleanupFn?:CleanupFn;

  connect() {
    this.cleanupFn = combine(
      draggable({
        element: this.element,
        getInitialData: () => this.getItemData(),
        onDragStart: () => {
          this.setState({ type: 'is-dragging' });
        },
        onDrop: () => {
          this.setState(idle);
        },
      }),
      dropTargetForElements({
        element: this.element,
        canDrop: ({ source }) => {
          if (source.element === this.element) {
            return false;
          }

          return isItemData(source.data);
        },
        getData: ({ input }) => {
          return attachClosestEdge(this.getItemData(), {
            element: this.element,
            input,
            allowedEdges: ['top', 'bottom'],
          });
        },
        getIsSticky: () => true,
        onDragEnter: ({ self }) => {
          const closestEdge = extractClosestEdge(self.data);
          this.setState({ type: 'is-dragging-over', closestEdge });
        },
        onDrag: ({ self }) => {
          const closestEdge = extractClosestEdge(self.data);

          this.setState((current) => {
            if (current.type === 'is-dragging-over' && current.closestEdge === closestEdge) {
              return current;
            }

            return { type: 'is-dragging-over', closestEdge };
          });
        },
        onDragLeave: () => {
          this.setState(idle);
        },
        onDrop: () => {
          this.setState(idle);
        },
      }),
    );
  }

  disconnect() {
    this.cleanupFn?.();
  }

  private setState(next:ItemState | ((current:ItemState) => ItemState)) {
    const newState = typeof next === 'function' ? next(this.state) : next;

    if (
      this.state.type === newState.type &&
      this.state.type === 'is-dragging-over' &&
      newState.type === 'is-dragging-over' &&
      this.state.closestEdge === newState.closestEdge
    ) {
      return;
    }

    this.state = newState;
    this.renderState();
  }

  private renderState() {
    this.element.classList.toggle('op-backlogs-story--dragging', this.state.type === 'is-dragging');

    // create/update/remove drop indicator here based on:
    // this.state.type === 'is-dragging-over' && this.state.closestEdge
  }

  private getItemData():ItemData {
    return itemData(this.itemIdValue);
  }
}

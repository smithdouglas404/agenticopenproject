/* eslint-disable no-plusplus */

import { computed, inject, Injectable, signal } from '@angular/core';
import { toObservable } from '@angular/core/rxjs-interop';
import { GridWidgetArea } from 'core-app/shared/components/grids/areas/grid-widget-area';
import { GridArea } from 'core-app/shared/components/grids/areas/grid-area';
import { GridGap } from 'core-app/shared/components/grids/areas/grid-gap';
import { GridResource } from 'core-app/features/hal/resources/grid-resource';
import { GridWidgetResource } from 'core-app/features/hal/resources/grid-widget-resource';
import { SchemaResource } from 'core-app/features/hal/resources/schema-resource';
import { WidgetChangeset } from 'core-app/shared/components/grids/widgets/widget-changeset';
import { ToastService } from 'core-app/shared/components/toaster/toast.service';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { firstValueFrom } from 'rxjs';
import { ApiV3Service } from 'core-app/core/apiv3/api-v3.service';
import { ApiV3GridForm } from 'core-app/core/apiv3/endpoints/grids/apiv3-grid-form';
import { map } from 'rxjs/operators';

@Injectable()
export class GridAreaService {
  private readonly apiV3Service = inject(ApiV3Service);
  private readonly toastService = inject(ToastService);
  private readonly i18n = inject(I18nService);

  private resource!:GridResource;

  private _schema = signal<SchemaResource|null>(null);
  private _numColumns = signal(0);
  private _numRows = signal(0);

  private _gridAreas = signal<GridArea[]>([]);
  private _gridGaps = signal<GridArea[]>([]);
  private _widgetAreas = signal<GridWidgetArea[]>([]);
  private _gridAreaIds = signal<string[]>([]);

  private _helpMode = signal(false);
  private _mousedOverArea = signal<GridArea|null>(null);

  readonly schema = this._schema.asReadonly();
  readonly numColumns = this._numColumns.asReadonly();
  readonly numRows = this._numRows.asReadonly();

  readonly gridAreas = this._gridAreas.asReadonly();
  readonly gridGaps = this._gridGaps.asReadonly();
  readonly widgetAreas = this._widgetAreas.asReadonly();
  readonly gridAreaIds = this._gridAreaIds.asReadonly();

  readonly isSingleCell = computed(() => this.numRows() === 1 && this.numColumns() === 1 && this.gridAreas().length === 0);
  readonly inHelpMode = computed(() => this._helpMode() || this.isSingleCell());
  readonly mousedOverArea = this._mousedOverArea.asReadonly();

  readonly $schema = toObservable(this._schema);
  readonly $mousedOverArea = toObservable(this._mousedOverArea);

  setSchema(schema:SchemaResource|null) {
    this._schema.set(schema);
  }

  setGridSize(cols:number, rows:number) {
    this._numColumns.set(cols);
    this._numRows.set(rows);
  }

  setNumRows(rows:number) {
    this._numRows.set(rows);
  }

  setNumRowsMax(rows:number) {
    this._numRows.update((currRows) => Math.max(currRows, rows));
  }

  setNumCols(cols:number) {
    this._numColumns.set(cols);
  }

  setGridAreas(areas:GridArea[]) {
    this._gridAreas.set([...areas]);
  }

  setGridGaps(gaps:GridArea[]) {
    this._gridGaps.set([...gaps]);
  }

  setWidgetAreas(areas:GridWidgetArea[]) {
    this._widgetAreas.set([...areas]);
  }

  addWidgetArea(area:GridWidgetArea) {
    this._widgetAreas.update((list) => [...list, area]);
  }

  setGridAreaIds(ids:string[]) {
    this._gridAreaIds.set([...ids]);
  }

  setHelpMode(helpMode:boolean) {
    this._helpMode.set(helpMode);
  }

  toggleHelpMode() {
    this._helpMode.update((value) => !value);
  }

  setMousedOverArea(area:GridArea|null) {
    this._mousedOverArea.set(area);
  }

  public set gridResource(value:GridResource) {
    this.resource = value;
    this.fetchSchema();

    this.setGridSize(this.resource.columnCount, this.resource.rowCount);
    this.buildAreas(true);
  }

  public get gridResource() {
    return this.resource;
  }

  public cleanupUnusedAreas() {
    // array containing Numbers from this.numRows to 1
    let unusedRows = _.range(this.numRows(), 0, -1);

    this.widgetAreas().forEach((widget) => {
      unusedRows = unusedRows.filter((item) => item !== widget.startRow);
    });

    unusedRows.forEach((number) => {
      if (this.numRows() > 1) {
        this.removeRow(number);
      }
    });

    let unusedColumns = _.range(this.numColumns(), 0, -1);

    this.widgetAreas().forEach((widget) => {
      unusedColumns = unusedColumns.filter((item) => item !== widget.startColumn);
    });

    unusedColumns.forEach((number) => {
      if (this.numColumns() > 1) {
        this.removeColumn(number);
      }
    });
  }

  public buildAreas(widgets = false) {
    this.setGridAreas(this.buildGridAreas());
    this.setGridGaps(this.buildGridGaps());
    this.setGridAreaIds(this.buildGridAreaIds());
    if (widgets) {
      this.setWidgetAreas(this.buildGridWidgetAreas());
    }
  }

  public async rebuildAndPersist():Promise<GridResource> {
    const resource = await this.persist();
    this.buildAreas(false);
    return resource;
  }

  public persist() {
    this._numRows.set(
      (this.widgetAreas()
        .map((area) => area.endRow)
        .sort((a, b) => a - b)
        .pop() ?? 2) - 1
    );
    this.resource.rowCount = this.numRows();
    this.resource.columnCount = this.numColumns();

    this.writeAreaChangesToWidgets();
    return this.saveGrid(this.resource, this.schema()!);
  }

  public saveWidgetChangeset(changeset:WidgetChangeset) {
    const payload = ApiV3GridForm.extractPayload(this.resource, this.schema()) as GridResource;

    const payloadWidget = payload.widgets.find((w) => w.id === changeset.pristineResource.id)!;
    Object.assign(payloadWidget, changeset.changes);

    // Adding the id so that the url can be deduced
    payload.id = this.resource.id;

    this.saveGrid(payload);
  }

  public isGap(area:GridArea) {
    return area instanceof GridGap;
  }

  // This is a hacky way to have the placeholder in the viewport.
  // It is a noop for firefox and edge as both do not support scrollIntoViewIfNeeded.
  // But as scrollIntoView will always readjust the viewport, the result would be an unbearable flicker
  // which causes e.g. dragging to be impossible.
  public scrollPlaceholderIntoView() {
    const placeholder = jQuery('.grid--area.-placeholder');

    if ((placeholder[0] as any).scrollIntoViewIfNeeded) {
      setTimeout(() => (placeholder[0] as any).scrollIntoViewIfNeeded());
    }
  }

  private async saveGrid(resource:GridResource, schema?:SchemaResource):Promise<GridResource> {
    const subscription = this
      .apiV3Service
      .grids
      .id(resource)
      .patch(resource, schema)
      .pipe(
        map((updatedGrid) => {
          this.assignAreasWidget(updatedGrid);
          this.toastService.addSuccess(this.i18n.t('js.notice_successful_update'));

          return updatedGrid;
        }),
      );

    return firstValueFrom(subscription);
  }

  private assignAreasWidget(newGrid:GridResource) {
    this.resource.widgets = newGrid.widgets;

    this._widgetAreas.update((areas) => {
      const takenIds = areas.map((a) => a.widget.id);

      areas.forEach((area) => {
        let newWidget:GridWidgetResource;

        // identify the right resource for the area. Typically that means fetching them by id.
        // But new areas have unpersisted resources at first. Unpersisted resources have no id.
        // In those cases, we find the one resource which is not claimed by any other area.
        if (area.widget.id) {
          newWidget = newGrid.widgets.find((widget) => widget.id === area.widget.id)!;
        } else {
          newWidget = newGrid.widgets.find(
            (widget) =>
              !takenIds.includes(widget.id) &&
              widget.identifier === area.widget.identifier &&
              widget.startRow === area.widget.startRow &&
              widget.startColumn === area.widget.startColumn
          )!;
        }

        area.widget = newWidget;
      });

      return areas;
    });
  }

  private buildGridAreas() {
    const cells:GridArea[] = [];

    // the one extra row is added in case the user wants to drag a widget to the very bottom
    const rows = this.numRows() + 1;
    for (let row = 1; row <= rows; row++) {
      cells.push(...this.buildGridAreasRow(row));
    }

    return cells;
  }

  private buildGridGaps() {
    const cells:GridGap[] = [];

    // special case where we want no gaps
    if (this.isSingleCell()) {
      return cells;
    }

    const rows = this.numRows() + 1;
    for (let row = 1; row <= rows; row++) {
      cells.push(...this.buildGridGapRow(row));
    }

    return cells;
  }

  private buildGridAreasRow(row:number) {
    const cells:GridArea[] = [];
    const columns = this.numColumns();

    for (let column = 1; column <= columns; column++) {
      const cell = new GridArea(row, row + 1, column, column + 1);

      cells.push(cell);
    }

    return cells;
  }

  private buildGridGapRow(row:number) {
    const cells:GridGap[] = [];
    const columns = this.numColumns();
    const rows = this.numRows();

    for (let column = 1; column <= columns; column++) {
      cells.push(new GridGap(row, row + 1, column, column + 1, 'row'));
    }

    if (row <= rows) {
      for (let column = 1; column <= columns + 1; column++) {
        cells.push(new GridGap(row, row + 1, column, column + 1, 'column'));
      }
    }

    return cells;
  }

  private buildGridWidgetAreas() {
    return this.widgetResources.map((widget) => new GridWidgetArea(widget));
  }

  // persist all changes to the areas caused by dragging/resizing
  // to the widget
  public writeAreaChangesToWidgets() {
    this._widgetAreas.update((areas) => {
      areas.forEach((area) => {
        area.writeAreaChangeToWidget();
      });
      return areas;
    });
  }

  public addColumn(column:number, excludeRow:number) {
    this._numColumns.update((cols) => cols + 1);

    const movedWidgets:GridWidgetArea[] = [];
    const rows = this.numRows();

    for (let row = 1; row <= rows; row++) {
      if (row === excludeRow) {
        continue;
      }

      const widget = this
        .rowWidgets(row)
        .sort((a, b) => a.startColumn - b.startColumn)
        .find((w) => !(w.startRow < excludeRow && w.endRow > excludeRow)
          && (w.startColumn === column + 1
            || w.endColumn === column + 1
            || (w.startColumn <= column && w.endColumn > column)));

      if (widget) {
        movedWidgets.push(widget);
        widget.endColumn++;
      }
    }

    this._widgetAreas.update((areas) => {
      this.moveSubsequentRowWidgets(
        areas.filter((widget) => !movedWidgets.includes(widget)),
        column
      );
      return areas;
    });
  }

  public addRow(row:number, excludeColumn:number) {
    this._numRows.update((rows) => rows + 1);

    const movedWidgets:GridWidgetArea[] = [];

    for (let column = 1; column <= this.numColumns(); column++) {
      if (column === excludeColumn) {
        continue;
      }

      const widget = this.columnWidgets(column)
        .sort((a, b) => a.startRow - b.startRow)
        .find(
          (w) =>
            !(w.startColumn < excludeColumn && w.endColumn > excludeColumn) &&
            (w.startRow === row + 1 || w.endRow === row + 1 || (w.startRow <= row && w.endRow > row))
        );

      if (widget) {
        movedWidgets.push(widget);
        widget.endRow++;
      }
    }

    this._widgetAreas.update((areas) => {
      this.moveSubsequentColumnWidgets(
        areas.filter((widget) => !movedWidgets.includes(widget)),
        row
      );
      return areas;
    });
  }

  public removeColumn(column:number) {
    this._numColumns.update((cols) => cols - 1);

    this._widgetAreas.update((areas) => {
      // shrink widgets that span more than the removed column
      areas.forEach((widget) => {
        if (widget.startColumn <= column && widget.endColumn >= column + 1) {
          // shrink widgets that span more than the removed column
          widget.endColumn--;
        }
      });

      // move all widgets that are after the removed column
      // so that they appear to keep their place.
      areas
        .filter((widget) => widget.startColumn > column)
        .forEach((widget) => {
          widget.startColumn--;
          widget.endColumn--;
        });

      return areas;
    });
  }

  public removeRow(row:number) {
    this._numRows.update((rows) => rows - 1);

    this._widgetAreas.update((areas) => {
      // shrink widgets that span more than the removed row
      areas.forEach((widget) => {
        if (widget.startRow <= row && widget.endRow >= row + 1) {
          // shrink widgets that span more than the removed row
          widget.endRow--;
        }
      });

      // move all widgets that are after the removed row
      // so that they appear to keep their place.
      areas
        .filter((widget) => widget.startRow > row)
        .forEach((widget) => {
          widget.startRow--;
          widget.endRow--;
        });

      return areas;
    });
  }

  public resetAreas(ignoredArea:GridWidgetArea|null = null) {
    this._widgetAreas.update((areas) => {
      areas
        .filter((area) => !ignoredArea || area.guid !== ignoredArea.guid)
        .forEach((area) => {
          area.reset();
        });

      return areas;
    });

    this.setGridSize(this.resource.columnCount, this.resource.rowCount);
  }

  public get isEditable() {
    return this.gridResource.updateImmediately !== undefined;
  }

  private buildGridAreaIds() {
    return this
      .gridAreas()
      .filter((area) => !this.isGap(area))
      .map((area) => area.guid);
  }

  private fetchSchema() {
    this
      .apiV3Service
      .grids
      .id(this.resource)
      .form
      .post({})
      .subscribe((form) => {
        this.setSchema(form.schema);
      });
  }

  public removeWidget(removedWidget:GridWidgetResource) {
    let index = this.resource.widgets.findIndex((widget) => widget.id === removedWidget.id);
    this.resource.widgets.splice(index, 1);

    this._widgetAreas.update((areas) => {
      index = areas.findIndex((area) => area.widget.id === removedWidget.id);
      areas.splice(index, 1);

      return areas;
    });

    this.cleanupUnusedAreas();

    void this.rebuildAndPersist();
  }

  public get widgetResources() {
    return this.resource.widgets;
  }

  private rowWidgets(row:number) {
    return this.widgetAreas().filter((widget) => widget.startRow === row);
  }

  private moveSubsequentRowWidgets(rowWidgets:GridWidgetArea[], column:number) {
    rowWidgets.forEach((subsequentWidget) => {
      if (subsequentWidget.startColumn > column) {
        subsequentWidget.startColumn++;
        subsequentWidget.endColumn++;
      }
    });
  }

  private columnWidgets(column:number) {
    return this.widgetAreas().filter((widget) => widget.startColumn === column);
  }

  private moveSubsequentColumnWidgets(columnWidgets:GridWidgetArea[], row:number) {
    columnWidgets.forEach((subsequentWidget) => {
      if (subsequentWidget.startRow > row) {
        subsequentWidget.startRow++;
        subsequentWidget.endRow++;
      }
    });
  }

  clear() {
    this._schema.set(null);
    this._numColumns.set(0);
    this._numRows.set(0);
    this._gridAreas.set([]);
    this._gridGaps.set([]);
    this._widgetAreas.set([]);
    this._gridAreaIds.set([]);
    this._mousedOverArea.set(null);
  }
}

import { ChangeDetectorRef, Directive, OnDestroy, OnInit, Renderer2 } from '@angular/core';
import { GridInitializationService } from 'core-app/shared/components/grids/grid/initialization.service';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { GridResource } from 'core-app/features/hal/resources/grid-resource';
import { GridAddWidgetService } from 'core-app/shared/components/grids/grid/add-widget.service';
import { GridAreaService } from 'core-app/shared/components/grids/grid/area.service';
import { CurrentProjectService } from 'core-app/core/current-project/current-project.service';
import { ConfigurationService } from 'core-app/core/config/configuration.service';

@Directive()
export abstract class GridPageComponent implements OnInit, OnDestroy {
  constructor(
    readonly gridInitialization:GridInitializationService,
    // not used in the base class but will be used throughout the subclasses
    readonly pathHelper:PathHelperService,
    readonly currentProject:CurrentProjectService,
    readonly cdRef:ChangeDetectorRef,
    readonly addWidget:GridAddWidgetService,
    readonly renderer:Renderer2,
    readonly areas:GridAreaService,
    readonly configurationService:ConfigurationService,
  ) {}

  public grid:GridResource;

  ngOnInit() {
    this.renderer.addClass(document.body, 'widget-grid-layout');
    this
      .gridInitialization
      .initialize(this.gridScopePath())
      .subscribe((grid) => {
        this.grid = grid;
        this.cdRef.detectChanges();
      });
  }

  ngOnDestroy():void {
    this.renderer.removeClass(document.body, 'widget-grid-layout');
  }

  protected abstract gridScopePath():string;
}

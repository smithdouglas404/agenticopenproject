import { OverlayContainer } from "@angular/cdk/overlay";
import { Injectable } from "@angular/core";


@Injectable({
  providedIn: 'root',
})
export class QupayaOverlayContainer extends OverlayContainer {
private readonly containerStack: HTMLElement[] = [];

  addContainer(container: HTMLElement): void {
    if (this._containerElement) {
      this.containerStack.push(this._containerElement);
    }
    this._containerElement = container;
  }
  removeContainer(): void {
    this._containerElement = this.containerStack.pop() as HTMLElement;
  }

}

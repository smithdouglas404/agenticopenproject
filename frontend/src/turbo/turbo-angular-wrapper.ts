import { initializeServices, runBootstrap } from 'core-app/app.module';
import { CurrentProjectService } from 'core-app/core/current-project/current-project.service';

export function addTurboAngularWrapper() {
  // When turbo:render fires, the Angular application needs to be rebootstrapped.
  // However, we first need to clean up components that are already initialized.
  document.addEventListener('turbo:before-render', () => {
    void window.OpenProject.getPluginContext().then(({ appRef }) => {
      // Remove all previous references to components
      // This is mainly the base component
      appRef.components.slice().forEach((component) => {
        appRef.detachView(component.hostView);
        component.destroy();
      });
    });
  });

  document.addEventListener('turbo:render', () => {
    void window.OpenProject.getPluginContext().then(({ appRef }) => {
      runBootstrap(appRef);
      initializeServices(appRef.injector)();
    });
  });

  document.addEventListener('turbo:load', () => {
    void window.OpenProject.getPluginContext().then(({ appRef:{ injector } }) => {
      const currentProject = injector.get(CurrentProjectService);
      currentProject.detect();
    });
  });
}

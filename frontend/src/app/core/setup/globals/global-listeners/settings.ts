import { retrieveCkEditorInstance } from 'core-app/shared/helpers/ckeditor-helpers';
import { hideElement, showElement, toggleElement } from 'core-app/shared/helpers/dom-helpers';
import invariant from 'tiny-invariant';

/**
 * Move from legacy app/assets/javascripts/application.js.erb
 *
 * This should not be loaded globally and ideally refactored into components
 */
export function listenToSettingChanges() {
  const ttlEnabled = document.querySelector<HTMLInputElement>('#settings_session_ttl_enabled');
  ttlEnabled?.addEventListener('change', () => {
    toggleElement(document.querySelector('#settings_session_ttl_container')!, ttlEnabled.checked);
  });
  ttlEnabled?.dispatchEvent(new Event('change', { bubbles: true }));

  /** Sync SCM vendor select when enabled SCMs are changed */
  const enabledScm = document.querySelector<HTMLInputElement>('[name="settings[enabled_scm][]"]');
  enabledScm?.addEventListener('change', (event) => {
    const checkbox = event.target as HTMLInputElement;
    const wasDisabled = !checkbox.checked;
    const vendor = checkbox.value;
    const select = document.querySelector<HTMLSelectElement>('#settings_repositories_automatic_managed_vendor')!;
    const option = select.querySelector<HTMLOptionElement>(`option[value="${vendor}"]`);

    // Skip non-manageable SCMs
    if (!option) {
      return;
    }

    option.disabled = wasDisabled;
    if (wasDisabled && option.selected) {
      select.value = '';
    }
  });

  /* Javascript for Settings::TextSettingComponent */
  const langSelectSwitchData = (select:HTMLSelectElement) => {
    const id = select.getAttribute('id') || '';
    const settingName = id.replace('lang-for-', '');
    const newLang = select.value;
    const textAreaId = `settings-${settingName}`;
    const textArea = document.getElementById(textAreaId);
    invariant(textArea, `Expected textarea "${textAreaId}"`);
    const ckEditor = document.querySelector<HTMLElement>(`opce-ckeditor-augmented-textarea[data-text-area-id='"${textAreaId}"'`);
    invariant(ckEditor, `Expected ckEditor for augmented textarea "${textAreaId}"`);
    const editor = retrieveCkEditorInstance(ckEditor);
    invariant(editor, `Expected ckEditorInstance for augmented textarea "${textAreaId}"`);

    return {
      id, settingName, newLang, textArea, editor,
    };
  };

  // Upon focusing:
  //   * store the current value of the editor in the hidden field for that lang.
  // Upon change:
  //   * get the current value from the hidden field for that lang and set the editor text to that value.
  //   * Set the name of the textarea to reflect the current lang so that the value stored in the hidden field
  //     is overwritten.

  const langSelectSwitchFocusListener = (ev:Event) => {
    const select = ev.currentTarget as HTMLSelectElement;
    const { id, newLang, editor } = langSelectSwitchData(select);
    const hiddenInput = document.querySelector<HTMLInputElement>(`#${id}-${newLang}`)!;
    hiddenInput.value = editor.getData();
  };

  const langSelectSwitchChangeListener = (ev:Event) => {
    const select = ev.currentTarget as HTMLSelectElement;
    const { id, settingName, newLang, textArea, editor } = langSelectSwitchData(select);
    const hiddenInput = document.querySelector<HTMLInputElement>(`#${id}-${newLang}`)!;
    editor.setData(hiddenInput.value);
    textArea.setAttribute('name', `settings[${settingName}][${newLang}]`);
  };

  document.querySelectorAll<HTMLSelectElement>('.lang-select-switch')
    .forEach((selectSwitch) => {
      selectSwitch.addEventListener('focus', langSelectSwitchFocusListener);
      selectSwitch.addEventListener('change', langSelectSwitchChangeListener);
    });
  /* end Javascript for Settings::TextSettingComponent */

  /** Toggle notification settings fields */
  const emailDeliveryMethodSwitch = document.querySelector<HTMLSelectElement>('#email_delivery_method_switch');
  emailDeliveryMethodSwitch?.addEventListener('change', (event) => {
    const delivery_method = (event.target as HTMLSelectElement).value;
    document
      .querySelectorAll<HTMLElement>('.email_delivery_method_settings')
      .forEach((elem) => hideElement(elem));
    showElement(document.querySelector(`#email_delivery_method_${delivery_method}`)!);
  });
  emailDeliveryMethodSwitch?.dispatchEvent(new Event('change', { bubbles: true }));

  document.querySelector<HTMLSelectElement>('#settings_smtp_authentication')?.addEventListener('change', (event) => {
    const isNone = (event.target as HTMLSelectElement).value === 'none';
    document
      .querySelectorAll('#settings_smtp_user_name,#settings_smtp_password')
      .forEach((field) => toggleElement(field.closest('.form--field')!, !isNone));
  });

  /** Toggle repository checkout fieldsets required when option is disabled */
  document.querySelectorAll<HTMLInputElement>('.settings-repositories--checkout-toggle').forEach((toggle) => {
    toggle.addEventListener('change', (event) => {
      const wasChecked = (event.target as HTMLInputElement).checked;
      const fieldset = toggle.closest('fieldset')!;
      fieldset
        .querySelectorAll<HTMLInputElement|HTMLSelectElement>('input,select:not([type=checkbox],[type=hidden])')
        .forEach((field) => { field.required = wasChecked; });
    });
  });

  /** Toggle highlighted attributes visibility depending on if the highlighting mode 'inline' was selected */
  document.querySelector<HTMLSelectElement>('.settings--highlighting-mode select')?.addEventListener('change', (event) => {
    const highlightingMode = (event.target as HTMLSelectElement).value;
    document.querySelectorAll<HTMLElement>('.settings--highlighted-attributes')
      .forEach((elem) => { toggleElement(elem, highlightingMode === 'inline'); });
  });

  document.querySelector<HTMLFormElement>('#tab-content-work_packages form')?.addEventListener('submit', () => {
    const availableAttributes = document.querySelectorAll<HTMLInputElement>(".settings--highlighted-attributes input[type='checkbox']");
    const selectedAttributes = document.querySelectorAll<HTMLInputElement>(".settings--highlighted-attributes input[type='checkbox']:checked");
    if (selectedAttributes.length === availableAttributes.length) {
      availableAttributes.forEach((availableAttribute) => { availableAttribute.checked = false; });
    }
  });
}

import { retrieveCkEditorInstance } from 'core-app/shared/helpers/ckeditor-helpers';
import invariant from 'tiny-invariant';

/**
 * Move from legacy app/assets/javascripts/application.js.erb
 *
 * This should not be loaded globally and ideally refactored into components
 */
export function listenToSettingChanges() {
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
}

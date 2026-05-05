# frozen_string_literal: true

module FormFields
  module Primerized
    class BlockNoteEditorInput
      include Capybara::DSL

      def open_command_dialog
        send_keys_to_editor("/")
      end

      def open_add_image_dialog
        send_keys_to_editor("/image")
        send_keys(:enter)
      end

      def open_add_work_package_dialog
        send_keys_to_editor("/work package")
        send_keys(:enter)
      end

      def fill_in(content)
        send_keys_to_editor(content)
      end

      def attach_file(path)
        input = shadow_root.find("input[type='file']", visible: false)
        input.attach_file(path, make_visible: true)
      end

      def content
        # capybara does not yet support getting content directly
        # on shadow roots
        page.evaluate_script(<<~JS)
          document.querySelector('op-block-note')
            .shadowRoot
            .innerHTML;
        JS
      end

      def shadow_root
        page.find("op-block-note").shadow_root
      end

      # Simulates pasting one or more links into the editor — a common user
      # interaction (e.g. copying a link from an email or browser and pasting it).
      #
      # Uses a synthetic ClipboardEvent because the Ctrl+K link insertion requires
      # the formatting toolbar to be visible (text must be selected first), which
      # has no reliable programmatic equivalent in Capybara/Selenium. The synthetic
      # event exercises the same ProseMirror paste handler code path as a real Ctrl+V.
      #
      # @example Single link
      #   editor.paste_links(text: "Example", url: "https://example.com")
      #
      # @example Multiple links
      #   editor.paste_links(
      #     { text: "One", url: "https://one.com" },
      #     { text: "Two", url: "https://two.com" }
      #   )
      def paste_links(*links)
        el = element
        el.click

        html = links.map { |l| %(<a href="#{l[:url]}">#{l[:text]}</a>) }.join(" ")
        plain = links.pluck(:text).join(" ")

        page.execute_script(<<~JS, el.native, html, plain)
          const el = arguments[0];
          const dt = new DataTransfer();
          dt.setData('text/html', arguments[1]);
          dt.setData('text/plain', arguments[2]);
          el.dispatchEvent(new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true }));
        JS
      end

      def element
        shadow_root.find("div[role='textbox']")
      end

      private

      # Attention: This only works with selenium, not with cuprite,
      # as cuprite does not support shadow dom (yet).
      def send_keys_to_editor(keys)
        element.send_keys(keys)
      end
    end
  end
end

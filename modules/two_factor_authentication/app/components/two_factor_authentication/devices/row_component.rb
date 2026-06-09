# frozen_string_literal: true

module ::TwoFactorAuthentication
  module Devices
    class RowComponent < ::OpPrimer::BorderBoxRowComponent
      def device
        model
      end

      def row_css_class
        is_default = "blocked" if device.default

        ["mobile-otp--two-factor-device-row", is_default].compact.join(" ")
      end

      def device_type
        device.identifier
      end

      def default
        if device.default
          render(Primer::Beta::Octicon.new(icon: :check))
        else
          "-"
        end
      end

      def confirmed
        if device.active
          render(Primer::Beta::Octicon.new(icon: :check))
        elsif table.self_table?
          link_to t("two_factor_authentication.devices.confirm_now"),
                  { controller: table.target_controller, action: :confirm, device_id: device.id }
        else
          render(Primer::Beta::Octicon.new(icon: :x))
        end
      end

      ###

      def button_links
        links = []
        links << make_default_button unless device.default
        links << delete_button

        links
      end

      def make_default_button
        helpers.form_tag(
          { controller: table.target_controller, action: :make_default, device_id: device.id },
          method: :post,
          id: "two_factor_make_default_form",
          data: helpers.password_confirmation_data_attribute({})
        ) do
          render(
            Primer::Beta::IconButton.new(
              icon: :star,
              tag: :button,
              size: :small,
              type: :submit,
              "aria-label": I18n.t(:button_make_default)
            )
          )
        end
      end

      def delete_button
        helpers.form_tag(
          { controller: table.target_controller, action: :destroy, device_id: device.id },
          method: :delete,
          id: "two_factor_delete_form",
          data: helpers.password_confirmation_data_attribute({})
        ) do
          render(
            Primer::Beta::IconButton.new(
              scheme: :danger,
              icon: :trash,
              tag: :button,
              size: :small,
              type: :submit,
              disabled: deletion_blocked?,
              "aria-label": if deletion_blocked?
                              I18n.t("two_factor_authentication.devices.is_default_cannot_delete")
                            else
                              I18n.t(:button_delete)
                            end
            )
          )
        end
      end

      def deletion_blocked?
        return false if table.admin_table?

        device.default && table.enforced?
      end
    end
  end
end

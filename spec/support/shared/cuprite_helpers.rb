# frozen_string_literal: true

# -- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
# ++
#

# Wrapper for Cuprite's `page.driver.wait_for_network_idle`
# Used to wait for Network traffic to become idle, helping
# in specs where AJAX requests are performed by angular components.
# This is especially helpful as it doesn't depend on DOM elements
# being present or gone. Instead the execution is halted until
# requested data is done being fetched.
def wait_for_network_idle(...)
  if using_cuprite?
    page.driver.wait_for_network_idle(...)
  else
    warn_about_cuprite_helper_misuse(:wait_for_network_idle)
  end
end

# Takes the above `wait_for_network_idle` a step further by waiting
# for the page to be reloaded after some triggering action.
def wait_for_reload
  if using_cuprite?
    page.driver.wait_for_reload
  else
    warn_about_cuprite_helper_misuse(:wait_for_reload)
  end
end

def warn_about_cuprite_helper_misuse(method_name)
  # Don't bloat the output of the CI
  return if ENV["CI"]

  stack = caller(2)
  cause = [stack[0], stack.find { |line| line["_spec.rb:"] }].uniq.join(" … ")
  warn "#{method_name} used in spec not using cuprite (#{cause})"
end

# Ferrum is yet support `fill_options` as a Hash
def clear_input_field_contents(input_element)
  if input_element.is_a? String
    input_element = find_field(input_element)
  end

  return unless input_element.value.length.positive?

  # Move to the end of the input field and then backspace to clear the field.
  rights = Array.new(input_element.value.length, :right)
  backspaces = Array.new(input_element.value.length, :backspace)
  input_element.native.node.type(*rights)
  input_element.native.node.type(*backspaces)
end

# Executes the given block and waits for a Turbo Drive navigation to complete.
#
# Sets up a listener for turbo:load BEFORE yielding, avoiding the race
# condition where the navigation completes before the listener is registered.
#
# @example
#   wait_for_turbo { click_link_or_button "Save" }
#   expect(page).to have_text("Saved")
#
def wait_for_turbo(&block)
  unless using_cuprite?
    yield if block
    return
  end

  page.execute_script(<<~JS)
    window.__opTurboLoaded = new Promise((resolve) => {
      document.addEventListener('turbo:load', () => resolve(true), { once: true });
    });
  JS

  yield

  page.driver.evaluate_async_script(<<~JS)
    window.__opTurboLoaded.then(() => {
      delete window.__opTurboLoaded;
      arguments[0](true);
    });
  JS
end

def using_cuprite?
  Capybara.javascript_driver == :better_cuprite_en
end

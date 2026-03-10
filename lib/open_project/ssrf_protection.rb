# frozen_string_literal: true

#-- copyright
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
#++

module OpenProject
  class SsrfProtection < ::SsrfFilter
    class << self
      ##
      # Given a hostname or IP address, returns the first one which is safe to use
      # for triggering a user initiated request.
      #
      # By default, private IP addresses are deemed not safe in the context of SSRF protection.
      # Use OPENPROJECT_SSRF_PROTECTION_IP_ALLOWLIST to allow specific private IPs anyway.
      #
      # @param hostname_or_ip_address [String] The hostname (e.g. localhost) or IP address (e.g. 127.0.0.1) to check
      # @return [IPAddr] The first safe IP address which can be used for a request, or `nil` if there aren't any
      def safe_ip?(hostname_or_ip_address)
        if hostname_or_ip_address.is_a? IPAddr
          safe_ip_address hostname_or_ip_address
        elsif [Resolv::IPv4::Regex, Resolv::IPv6::Regex].any? { |regex| hostname_or_ip_address =~ regex }
          safe_ip_address IPAddr.new(hostname_or_ip_address)
        else
          safe_ip_address_for_hostname hostname_or_ip_address
        end
      end

      def safe_ip_address_for_hostname(hostname)
        ip_addresses = resolver.call hostname

        ip_addresses.find { |addr| safe_ip_address addr }
      end

      def safe_ip_address(ip_address)
        ip_address if !unsafe_ip_address?(ip_address) || allowed_ip_address?(ip_address)
      end

      def allowed_ip_address?(ip_address)
        OpenProject::Configuration.ssrf_protection_ip_allowlist.any? { |addr| addr.include? ip_address }
      end

      def resolver
        SsrfFilter::DEFAULT_RESOLVER
      end
    end
  end
end

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
      def safe_ip_address(hostname_or_ip_address)
        if hostname_or_ip_address.is_a? IPAddr
          safe_ip_address? hostname_or_ip_address
        elsif [Resolv::IPv4::Regex, Resolv::IPv6::Regex].any? { |regex| hostname_or_ip_address =~ regex }
          safe_ip_address? IPAddr.new(hostname_or_ip_address)
        else
          safe_hostname? hostname_or_ip_address
        end
      end

      def safe_hostname?(hostname)
        ip_addresses = resolver.call hostname

        ip_addresses.find { |addr| safe_ip_address? addr }
      end

      def safe_ip_address?(ip_address)
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

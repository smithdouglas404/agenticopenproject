#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

class Tag
  def initialize(tag)
    @tag = tag
  end

  def semver?
    @tag.match?(/^v(\d+\.\d+\.\d+.*)$/)
  end

  def version
    @tag.sub(/^v/, "")
  end

  def to_semver_docker_tags
    if semver?
      [
        "type=semver,pattern={{version}},value=#{version}",
        "type=semver,pattern={{major}}.{{minor}},value=#{version}",
        "type=semver,pattern={{major}},value=#{version}",
      ]
    else
      ["type=raw,value=#{version}"]
    end
  end
  
  def major
    return unless semver?

    version.split(".")[0]
  end

  def minor
    return unless semver?

    version.split(".")[1]
  end
end


# rubocop:disable Metrics/AbcSize
def main
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [TAG] [options]"
    opts.on("--format-for-docker", "Output formatted tags for docker metadata") do
      options[:format_for_docker] = true
    end
    opts.on("--version", "Output first tag as version") do
      options[:version] = true
    end
    opts.on("-h", "--help", "Prints this help") do
      puts opts
      exit
    end
  end.parse!

  tag = Tag.new(ARGV.first)
  if options[:version]
    puts tag.version
  elsif options[:format_for_docker]
    puts tag.to_semver_docker_tags.join("\n")
  else
    puts "Error: Must specify either --version or --format-for-docker"
    exit 1
  end
end

main if __FILE__ == $0

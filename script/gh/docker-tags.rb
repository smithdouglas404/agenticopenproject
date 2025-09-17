#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "net/http"
require "json"

def latest_release_major_minor
  uri = URI("https://api.github.com/repos/opf/openproject/releases/latest")
  res = Net::HTTP.get_response(uri)
  if res.is_a?(Net::HTTPSuccess)
    tag_name = JSON.parse(res.body)["tag_name"]
    tag_name[/^v?(\d+\.\d+)/, 1]
  end
rescue StandardError
  puts "Error getting latest release major: #{$!}"
  nil
end

def generate_matrix
  latest_version = latest_release_major_minor
  return nil unless latest_version

  {
    "include" => [
      {
        "branch" => "dev",
        "tag" => "dev"
      },
      {
        "branch" => "release/#{latest_version}",
        "tag" => "#{latest_version}-rc"
      }
    ]
  }
end

class Tag
  def initialize(tag)
    @tag = tag
  end

  def semver?
    @tag.match?(/^v(\d+\.\d+\.\d+.*)$/)
  end

  def rc?
    @tag.match?(/-rc$/)
  end

  def version
    @tag.sub(/^v/, "").sub(/-rc$/, "")
  end

  def to_semver_docker_tags
    if semver?
      [
        "type=semver,pattern={{version}},value=#{version}",
        "type=semver,pattern={{major}}.{{minor}},value=#{version}",
        "type=semver,pattern={{major}},value=#{version}"
      ]
    elsif rc?
      latest_major_minor = latest_release_major_minor
      tags = [
        "type=raw,value=#{major}.#{minor}-rc",
        "type=raw,value=#{major}-rc"
      ]
      if latest_major_minor && latest_major_minor == [major, minor].join(".")
        tags << [
          "type=raw,value=rc"
        ]
      end
      tags
    else
      ["type=raw,value=#{version}"]
    end
  end

  def major
    return unless semver? || rc?

    version.split(".")[0]
  end

  def minor
    return unless semver? || rc?

    version.split(".")[1]
  end
end

def main # rubocop:disable Metrics/AbcSize
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [TAG] [options]"
    opts.on("--format-for-docker", "Output formatted tags for docker metadata") do
      options[:format_for_docker] = true
    end
    opts.on("--version", "Output first tag as version") do
      options[:version] = true
    end
    opts.on("--matrix", "Generate matrix for GitHub Actions workflow") do
      options[:matrix] = true
    end
    opts.on("-h", "--help", "Prints this help") do
      puts opts
      exit
    end
  end.parse!

  if options[:matrix]
    matrix = generate_matrix
    if matrix
      puts JSON.pretty_generate(matrix)
    else
      puts "Error: Could not generate matrix"
      exit 1
    end
  else
    tag = Tag.new(ARGV.first)
    if options[:version]
      puts tag.version
    elsif options[:format_for_docker]
      puts tag.to_semver_docker_tags.join("\n")
    else
      puts "Error: Must specify either --version, --format-for-docker, or --matrix"
      exit 1
    end
  end
end

main if __FILE__ == $0

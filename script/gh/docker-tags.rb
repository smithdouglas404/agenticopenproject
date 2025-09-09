#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'

class DockerTagsGenerator
  def initialize(tags_input)
    @tags_input = tags_input.strip
  end

  def generate_formatted_tags
    tags = parse_tags(@tags_input)
    format_for_docker_metadata(tags)
  end

  def generate_version
    parse_tags(@tags_input).first
  end

  private

  def parse_tags(input)
    input.split(',').map(&:strip).reject(&:empty?)
  end

  def format_for_docker_metadata(tags)
    tags.map { |tag| "type=raw,value=#{tag}" }.join("\n")
  end

  def self.generate_semver_tags(tag_ref)
    return [tag_ref] unless tag_ref.match?(/^v(\d+\.\d+\.\d+.*)$/)

    version = tag_ref.sub(/^v/, '')
    parts = version.split('.')
    major = parts[0]
    minor = "#{major}.#{parts[1]}" if parts[1]

    tags = [version]
    tags << minor if minor
    tags << major
    tags.uniq
  end
end

def main
  options = {}
  
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"
    
    opts.on("--tags TAGS", "Comma-separated list of tags") do |tags|
      options[:tags] = tags
    end
    
    opts.on("--semver TAG_REF", "Generate semver tags from tag reference") do |tag_ref|
      options[:semver] = tag_ref
    end
    
    opts.on("--format", "Output formatted tags for docker metadata") do
      options[:format] = true
    end
    
    opts.on("--version", "Output first tag as version") do
      options[:version] = true
    end
    
    opts.on("-h", "--help", "Prints this help") do
      puts opts
      exit
    end
  end.parse!

  if options[:semver]
    # Generate semver tags
    tags = DockerTagsGenerator.generate_semver_tags(options[:semver])
    if options[:format]
      generator = DockerTagsGenerator.new(tags.join(','))
      puts generator.generate_formatted_tags
    else
      puts tags.join(',')
    end
  elsif options[:tags]
    # Use provided tags
    generator = DockerTagsGenerator.new(options[:tags])
    if options[:format]
      puts generator.generate_formatted_tags
    elsif options[:version]
      puts generator.generate_version
    else
      puts options[:tags]
    end
  else
    puts "Error: Must specify either --tags or --semver"
    exit 1
  end
end

if __FILE__ == $0
  main
end
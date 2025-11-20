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

class Project::PDFExport::ProjectInitiation < Exports::Exporter
  include Exports::PDF::Common::Common
  include Exports::PDF::Common::Attachments
  include Exports::PDF::Common::Logo
  include Exports::PDF::Common::Macro
  include Exports::PDF::Common::Markdown
  include Exports::PDF::Components::Page
  include Exports::PDF::Components::Cover
  include Project::PDFExport::Common::ProjectAttributes
  include Project::PDFExport::ProjectInitiation::Styles

  attr_accessor :pdf

  self.model = Project

  alias :project :object

  def self.key
    :project_initiation_export_pdf
  end

  def initialize(project, _options = {})
    super

    @page_count = 0
    setup_page!
  end

  def setup_page!
    self.pdf = get_pdf
    configure_page_size!(:portrait)
    pdf.title = heading
  end

  def export!
    render_doc
    success(pdf.render)
  rescue StandardError => e
    Rails.logger.error "Failed to generate project creation PDF:  #{e.message}:\n#{e.backtrace.join("\n")}"
    error(I18n.t(:error_pdf_failed_to_export, error: e.message))
  ensure
    delete_all_resized_images
  end

  def render_doc
    render_project_initiation
    render_again_with_total_page_nrs
  end

  def render_again_with_total_page_nrs
    @total_page_nr = pdf.page_count + @page_count
    @page_count = 0
    setup_page! # clear current pdf
    render_project_initiation
  end

  def render_project_initiation
    write_cover_page! if with_cover?
    write_title!
    write_project_initiation
    write_headers_footers
  end

  def write_headers_footers
    write_logo!
    write_footers!
  end

  def export_datetime
    @export_datetime = Time.zone.now
  end

  def footer_date
    format_time(export_datetime)
  end

  def cover_page_dates
    nil
  end

  def cover_page_subheading
    nil
  end

  def cover_page_title
    project.name
  end

  def cover_page_heading
    heading
  end

  def heading
    I18n.t(:"export.project_initiation.title")
  end

  def footer_title
    "#{project.name} | #{cover_page_heading}"
  end

  def title
    # <project>_<project_initialization>_<YYYY-MM-DD>_<HH-MM>.pdf
    build_pdf_filename([project.name, heading].join("_"))
  end

  def with_images?
    true
  end

  def with_cover?
    true
  end

  def can_view_attribute?(_project, _attribute)
    true
  end

  def hide_empty_attributes?
    false
  end

  def enabled_in_wizard_ids
    project
      .project_custom_field_project_mappings
      .where(creation_wizard: true)
      .select(:custom_field_id)
  end

  def collect_custom_fields_data
    project.available_custom_fields
           .where(id: enabled_in_wizard_ids)
           .group_by(&:project_custom_field_section)
           .map do |section, custom_fields|
      {
        caption: section.name,
        fields: custom_fields.map do |custom_field|
          { key: "cf_#{custom_field.id}", caption: custom_field.name, custom_field: }
        end
      }
    end
  end

  def collect_base_data
    [
      { caption: I18n.t(:label_project),
        fields: %i[name description].map { |key| { key:, caption: Project.human_attribute_name(key) } } }
    ]
  end

  def collect_sections_data
    collect_base_data.concat collect_custom_fields_data
  end

  def write_section_title_hr
    hr_style = styles.section_title_hr
    write_horizontal_line(pdf.cursor, hr_style[:height], hr_style[:color])
  end

  def write_section_title(text)
    with_margin(styles.section_title_margins) do
      style = styles.section_title
      pdf.formatted_text([style.merge({ text: })], style)
      write_section_title_hr
    end
  end

  def write_section(section)
    with_margin(styles.section_margins) do
      write_section_title(section[:caption])
      write_project_detail_content(project, section[:fields])
    end
  end

  def write_project_initiation
    collect_sections_data.each do |section|
      next if section[:fields].empty?

      write_optional_page_break
      write_section(section)
    end
  end
end

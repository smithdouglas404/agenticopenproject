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

require "ttfunk"

class CustomStyle < ApplicationRecord
  mount_uploader :logo, OpenProject::Configuration.file_uploader
  mount_uploader :export_logo, OpenProject::Configuration.file_uploader
  mount_uploader :export_cover, OpenProject::Configuration.file_uploader
  mount_uploader :export_footer, OpenProject::Configuration.file_uploader
  mount_uploader :favicon, OpenProject::Configuration.file_uploader
  mount_uploader :touch_icon, OpenProject::Configuration.file_uploader
  mount_uploader :export_font_regular, OpenProject::Configuration.file_uploader
  mount_uploader :export_font_bold, OpenProject::Configuration.file_uploader
  mount_uploader :export_font_italic, OpenProject::Configuration.file_uploader
  mount_uploader :export_font_bold_italic, OpenProject::Configuration.file_uploader

  MAX_FONT_UPLOAD_SIZE = 30.megabytes
  validate :validate_font_files

  class << self
    def current
      RequestStore.fetch(:current_custom_style) do
        custom_style = CustomStyle.order(Arel.sql("created_at DESC")).first
        if custom_style.nil?
          return nil
        else
          custom_style
        end
      end
    end
  end

  def digest
    updated_at.to_i
  end

  %i(favicon touch_icon export_logo export_cover export_footer logo
     export_font_regular export_font_bold export_font_italic export_font_bold_italic).each do |name|
    define_method :"#{name}_path" do
      attachment = send(name)

      if attachment.readable?
        attachment.local_file.path
      end
    end

    define_method :"remove_#{name}" do
      attachment = send(name)
      attachment&.remove!

      if new_record?
        send(:"#{name}=", nil)
      else
        update_columns(name => nil, updated_at: Time.zone.now)
      end
    end
  end

  def validate_font_files
    %i(export_font_regular export_font_bold export_font_italic export_font_bold_italic).each do |name|
      attachment = send(name)
      validate_font_file(name, attachment)
    end
  end

  private

  def validate_font_file(name, attachment)
    validate_font_file_size(name, attachment) if attachment&.file
    validate_font_file_format(name, attachment) if attachment&.file
  end

  def validate_font_file_format(name, attachment)
    unless valid_ttf?(attachment.file.path)
      errors.add(name, I18n.t("admin.custom_styles.fonts.file_is_invalid"))
      attachment.remove!
    end
  end

  def validate_font_file_size(name, attachment)
    size = attachment.file.size.to_i
    if size >= MAX_FONT_UPLOAD_SIZE
      errors.add(name, I18n.t("admin.custom_styles.fonts.file_too_large", count: (MAX_FONT_UPLOAD_SIZE / 1.megabyte).to_i))
      attachment.remove!
    end
  end

  def valid_ttf?(filename)
    file = TTFunk::File.open(filename)
    file.name.font_name.present?
  rescue StandardError
    false
  end
end

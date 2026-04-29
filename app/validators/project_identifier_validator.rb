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

# Validates Project identifiers across the two supported formats (classic slug and
# semantic uppercase) plus reserved-keyword and historical-reservation rules.
#
# Bound to Project via the `Projects::Identifier` concern, which declares:
#   validates :identifier, project_identifier: true, if: :identifier_changed?
#
# Relies on the model exposing:
#   - Projects::Identifier::RESERVED_IDENTIFIERS / CLASSIC_IDENTIFIER_MAX_LENGTH /
#     SEMANTIC_IDENTIFIER_MAX_LENGTH (shared with acts_as_url, routing, suggesters)
#   - Project.classic_identifier_format? (shared with suggesters)
#   - Project.identifier_slugs (FriendlyId::Slug relation with custom scopes)
#   - Project#validation_context (the concern overrides this for :saving_custom_fields)
#
# Naming is top-level (not Projects::IdentifierValidator) so Rails' validator lookup
# resolves `validates :identifier, project_identifier: true` directly. Matches the
# convention of other validators in app/validators (UrlValidator, JsonValidator, etc.).
class ProjectIdentifierValidator < ActiveModel::EachValidator
  SEMANTIC_START_FORMAT = /\A[A-Z]/
  SEMANTIC_BODY_FORMAT  = /\A[A-Z0-9_]*\z/

  # @param record [Project]
  def validate_each(record, attribute, value)
    return if value.blank?

    validate_not_reserved_keyword(record, attribute, value)
    validate_format_for_mode(record, attribute, value)
    validate_not_historically_reserved(record, attribute, value)
  end

  private

  def validate_format_for_mode(record, attribute, value)
    if semantic_validation?(record)
      validate_semantic_format(record, attribute, value)
    else
      validate_classic_format(record, attribute, value)
    end
  end

  # Treat as semantic when the global setting is semantic, OR when the record is
  # being validated under the :semantic_conversion context (used by the converter
  # service to allow saving a semantic identifier on a classic-mode instance).
  def semantic_validation?(record)
    Setting::WorkPackageIdentifier.semantic? ||
      Array(record.validation_context).include?(:semantic_conversion)
  end

  def validate_classic_format(record, attribute, value)
    record.errors.add(attribute, :invalid) unless Project.classic_identifier_format?(value)
    max = Projects::Identifier::CLASSIC_IDENTIFIER_MAX_LENGTH
    record.errors.add(attribute, :too_long, count: max) if value.length > max
  end

  def validate_semantic_format(record, attribute, value)
    record.errors.add(attribute, :must_start_with_letter) unless value.match?(SEMANTIC_START_FORMAT)
    record.errors.add(attribute, :no_special_characters) unless value.match?(SEMANTIC_BODY_FORMAT)
    max = Projects::Identifier::SEMANTIC_IDENTIFIER_MAX_LENGTH
    record.errors.add(attribute, :too_long, count: max) if value.length > max
  end

  def validate_not_reserved_keyword(record, attribute, value)
    if Projects::Identifier::RESERVED_IDENTIFIERS.include?(value.downcase)
      record.errors.add(attribute, :exclusion)
    end
  end

  # Skips when the model's separately-declared `uniqueness:` validator already added
  # a :taken error — avoids piling on. Otherwise checks friendly_id_slugs for any
  # other project that previously used this identifier (case-insensitive).
  def validate_not_historically_reserved(record, attribute, value)
    return if uniqueness_already_failed?(record, attribute)
    return unless used_by_other_project_in_past?(record, value)

    record.errors.add(attribute, :taken, value: value)
  end

  def uniqueness_already_failed?(record, attribute)
    record.errors.any? { |e| e.attribute == attribute && e.type == :taken }
  end

  def used_by_other_project_in_past?(record, value)
    Project.identifier_slugs
           .for_identifier(value)
           .where.not(sluggable_id: record.id)
           .exists?
  end
end

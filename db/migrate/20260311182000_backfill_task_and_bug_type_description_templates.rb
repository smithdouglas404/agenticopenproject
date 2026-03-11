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
# See COPYRIGHT and LICENSE files for more details.
#++

class BackfillTaskAndBugTypeDescriptionTemplates < ActiveRecord::Migration[8.1]
  TASK_TEMPLATE = <<~MARKDOWN.strip.freeze
    ## Summary
    (What needs to be done)

    ## Goal / Expected outcome
    (Definition of done)

    ## Scope
    - In scope:
    - Out of scope:

    ## Acceptance criteria
    - [ ]
    - [ ]

    ## Dependencies / Links
    (Related work packages, docs, blockers)
  MARKDOWN

  BUG_TEMPLATE = <<~MARKDOWN.strip.freeze
    ## Summary
    (One-sentence defect summary and impact)

    ## Environment
    - Product/app version:
    - Browser + version:
    - OS/device + version:
    - Project:

    ## Steps to reproduce
    1.
    2.
    3.

    ## Expected behavior
    (What should happen)

    ## Actual behavior
    (What actually happens)

    ## Reproducibility
    - [ ] Always
    - [ ] Intermittent
    - [ ] Could not reproduce reliably

    ## Evidence
    (Logs, screenshots, links, crash IDs)

    ## Impact
    - Severity:
    - Priority:
    - Affected users/workflow:
  MARKDOWN

  def up
    set_template_if_blank("Task", TASK_TEMPLATE)
    set_template_if_blank("Bug", BUG_TEMPLATE)
  end

  def down
    # No-op
  end

  private

  def set_template_if_blank(type_name, template)
    quoted_type_name = connection.quote(type_name)
    quoted_template = connection.quote(template)

    execute <<~SQL
      UPDATE types
      SET description = #{quoted_template}
      WHERE name = #{quoted_type_name}
        AND (description IS NULL OR description = '')
    SQL
  end
end

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

module Exports::PDF::Common::ArabicShaping
  # Arabic character joining types
  # R = Right-joining (only joins to the right)
  # D = Dual-joining (joins both sides)
  # U = Non-joining
  # C = Join-causing (e.g. ZWJ)
  # T = Transparent (marks, don't affect joining)

  # Maps Arabic base characters to their presentation forms:
  # [isolated, final, initial, medial]
  # Values are Unicode codepoints for Arabic Presentation Forms-B (U+FE70-U+FEFF)
  ARABIC_FORMS = {
    # Hamza
    0x0621 => [0xFE80, nil, nil, nil], # HAMZA (U)
    # Alef with Madda, Hamza Above/Below, plain Alef
    0x0622 => [0xFE81, 0xFE82, nil, nil], # ALEF WITH MADDA ABOVE (R)
    0x0623 => [0xFE83, 0xFE84, nil, nil], # ALEF WITH HAMZA ABOVE (R)
    0x0624 => [0xFE85, 0xFE86, nil, nil], # WAW WITH HAMZA ABOVE (R)
    0x0625 => [0xFE87, 0xFE88, nil, nil], # ALEF WITH HAMZA BELOW (R)
    0x0626 => [0xFE89, 0xFE8A, 0xFE8B, 0xFE8C],         # YEH WITH HAMZA ABOVE (D)
    0x0627 => [0xFE8D, 0xFE8E, nil, nil], # ALEF (R)
    0x0628 => [0xFE8F, 0xFE90, 0xFE91, 0xFE92],         # BEH (D)
    0x0629 => [0xFE93, 0xFE94, nil, nil], # TEH MARBUTA (R)
    0x062A => [0xFE95, 0xFE96, 0xFE97, 0xFE98],         # TEH (D)
    0x062B => [0xFE99, 0xFE9A, 0xFE9B, 0xFE9C],         # THEH (D)
    0x062C => [0xFE9D, 0xFE9E, 0xFE9F, 0xFEA0],         # JEEM (D)
    0x062D => [0xFEA1, 0xFEA2, 0xFEA3, 0xFEA4],         # HAH (D)
    0x062E => [0xFEA5, 0xFEA6, 0xFEA7, 0xFEA8],         # KHAH (D)
    0x062F => [0xFEA9, 0xFEAA, nil, nil], # DAL (R)
    0x0630 => [0xFEAB, 0xFEAC, nil, nil], # THAL (R)
    0x0631 => [0xFEAD, 0xFEAE, nil, nil], # REH (R)
    0x0632 => [0xFEAF, 0xFEB0, nil, nil], # ZAIN (R)
    0x0633 => [0xFEB1, 0xFEB2, 0xFEB3, 0xFEB4],         # SEEN (D)
    0x0634 => [0xFEB5, 0xFEB6, 0xFEB7, 0xFEB8],         # SHEEN (D)
    0x0635 => [0xFEB9, 0xFEBA, 0xFEBB, 0xFEBC],         # SAD (D)
    0x0636 => [0xFEBD, 0xFEBE, 0xFEBF, 0xFEC0],         # DAD (D)
    0x0637 => [0xFEC1, 0xFEC2, 0xFEC3, 0xFEC4],         # TAH (D)
    0x0638 => [0xFEC5, 0xFEC6, 0xFEC7, 0xFEC8],         # ZAH (D)
    0x0639 => [0xFEC9, 0xFECA, 0xFECB, 0xFECC],         # AIN (D)
    0x063A => [0xFECD, 0xFECE, 0xFECF, 0xFED0],         # GHAIN (D)
    0x0640 => [0x0640, 0x0640, 0x0640, 0x0640],          # TATWEEL (kashida) (C)
    0x0641 => [0xFED1, 0xFED2, 0xFED3, 0xFED4],         # FEH (D)
    0x0642 => [0xFED5, 0xFED6, 0xFED7, 0xFED8],         # QAF (D)
    0x0643 => [0xFED9, 0xFEDA, 0xFEDB, 0xFEDC],         # KAF (D)
    0x0644 => [0xFEDD, 0xFEDE, 0xFEDF, 0xFEE0],         # LAM (D)
    0x0645 => [0xFEE1, 0xFEE2, 0xFEE3, 0xFEE4],         # MEEM (D)
    0x0646 => [0xFEE5, 0xFEE6, 0xFEE7, 0xFEE8],         # NOON (D)
    0x0647 => [0xFEE9, 0xFEEA, 0xFEEB, 0xFEEC],         # HEH (D)
    0x0648 => [0xFEED, 0xFEEE, nil, nil], # WAW (R)
    0x0649 => [0xFEEF, 0xFEF0, nil, nil], # ALEF MAKSURA (R)
    0x064A => [0xFEF1, 0xFEF2, 0xFEF3, 0xFEF4],         # YEH (D)

    # Additional Arabic characters
    0x0671 => [0xFB50, 0xFB51, nil, nil], # ALEF WASLA (R)
    0x0679 => [0xFB66, 0xFB67, 0xFB68, 0xFB69],         # TTEH (D)
    0x067A => [0xFB5E, 0xFB5F, 0xFB60, 0xFB61],         # TTEHEH (D)
    0x067B => [0xFB52, 0xFB53, 0xFB54, 0xFB55],         # BEEH (D)
    0x067E => [0xFB56, 0xFB57, 0xFB58, 0xFB59],         # PEH (D)
    0x067F => [0xFB62, 0xFB63, 0xFB64, 0xFB65],         # TEHEH (D)
    0x0680 => [0xFB5A, 0xFB5B, 0xFB5C, 0xFB5D],         # BEHEH (D)
    0x0683 => [0xFB76, 0xFB77, 0xFB78, 0xFB79],         # NYEH (D)
    0x0684 => [0xFB72, 0xFB73, 0xFB74, 0xFB75],         # DYEH (D)
    0x0686 => [0xFB7A, 0xFB7B, 0xFB7C, 0xFB7D],         # TCHEH (D)
    0x0687 => [0xFB7E, 0xFB7F, 0xFB80, 0xFB81],         # TCHEHEH (D)
    0x0688 => [0xFB88, 0xFB89, nil, nil], # DDAL (R)
    0x068C => [0xFB84, 0xFB85, nil, nil], # DAHAL (R)
    0x068D => [0xFB82, 0xFB83, nil, nil], # DDAHAL (R)
    0x068E => [0xFB86, 0xFB87, nil, nil], # DUL (R)
    0x0691 => [0xFB8C, 0xFB8D, nil, nil], # RREH (R)
    0x0698 => [0xFB8A, 0xFB8B, nil, nil], # JEH (R)
    0x06A4 => [0xFB6A, 0xFB6B, 0xFB6C, 0xFB6D],         # VEH (D)
    0x06A6 => [0xFB6E, 0xFB6F, 0xFB70, 0xFB71],         # PEHEH (D)
    0x06A9 => [0xFB8E, 0xFB8F, 0xFB90, 0xFB91],         # KEHEH (D)
    0x06AD => [0xFBD3, 0xFBD4, 0xFBD5, 0xFBD6],         # NG (D)
    0x06AF => [0xFB92, 0xFB93, 0xFB94, 0xFB95],         # GAF (D)
    0x06B1 => [0xFB9A, 0xFB9B, 0xFB9C, 0xFB9D],         # NGOEH (D)
    0x06B3 => [0xFB96, 0xFB97, 0xFB98, 0xFB99],         # GUEH (D)
    0x06BA => [0xFB9E, 0xFB9F, nil, nil], # NOON GHUNNA (R)
    0x06BB => [0xFBA0, 0xFBA1, 0xFBA2, 0xFBA3],         # RNOON (D)
    0x06BE => [0xFBAA, 0xFBAB, 0xFBAC, 0xFBAD],         # HEH DOACHASHMEE (D)
    0x06C0 => [0xFBA4, 0xFBA5, nil, nil], # HEH WITH YEH ABOVE (R)
    0x06C1 => [0xFBA6, 0xFBA7, 0xFBA8, 0xFBA9],         # HEH GOAL (D)
    0x06C5 => [0xFBE0, 0xFBE1, nil, nil], # KIRGHIZ OE (R)
    0x06C6 => [0xFBD9, 0xFBDA, nil, nil], # OE (R)
    0x06C7 => [0xFBD7, 0xFBD8, nil, nil], # U (R)
    0x06C8 => [0xFBDB, 0xFBDC, nil, nil], # YU (R)
    0x06C9 => [0xFBE2, 0xFBE3, nil, nil], # KIRGHIZ YU (R)
    0x06CB => [0xFBDE, 0xFBDF, nil, nil], # VE (R)
    0x06CC => [0xFBFC, 0xFBFD, 0xFBFE, 0xFBFF],         # FARSI YEH (D)
    0x06D0 => [0xFBE4, 0xFBE5, 0xFBE6, 0xFBE7],         # E (D)
    0x06D2 => [0xFBAE, 0xFBAF, nil, nil], # YEH BARREE (R)
    0x06D3 => [0xFBB0, 0xFBB1, nil, nil]                 # YEH BARREE WITH HAMZA ABOVE (R)
  }.freeze

  # Lam-Alef ligatures: when Lam (U+0644) is followed by certain Alef forms
  LAM_ALEF_LIGATURES = {
    0x0622 => [0xFEF5, 0xFEF6], # LAM + ALEF WITH MADDA ABOVE [isolated, final]
    0x0623 => [0xFEF7, 0xFEF8], # LAM + ALEF WITH HAMZA ABOVE [isolated, final]
    0x0625 => [0xFEF9, 0xFEFA], # LAM + ALEF WITH HAMZA BELOW [isolated, final]
    0x0627 => [0xFEFB, 0xFEFC]  # LAM + ALEF [isolated, final]
  }.freeze

  # Arabic diacritical marks (tashkeel) - transparent joining
  ARABIC_MARKS = (0x064B..0x065F).to_a.push(
    0x0610, 0x0611, 0x0612, 0x0613, 0x0614, 0x0615,
    0x0616, 0x0617, 0x0618, 0x0619, 0x061A,
    0x06D6, 0x06D7, 0x06D8, 0x06D9, 0x06DA, 0x06DB,
    0x06DC, 0x06DF, 0x06E0, 0x06E1, 0x06E2, 0x06E3,
    0x06E4, 0x06E7, 0x06E8, 0x06EA, 0x06EB, 0x06EC, 0x06ED,
    0x0670
  ).freeze

  ARABIC_MARKS_SET = ARABIC_MARKS.to_set.freeze

  class << self
    def contains_arabic?(text)
      text.match?(/[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]/)
    end

    # Shape Arabic text: convert characters to their correct positional presentation forms
    def shape(text)
      return text unless contains_arabic?(text)

      chars = text.codepoints
      result = []
      i = 0

      while i < chars.length
        if arabic_letter?(chars[i])
          run = collect_arabic_run(chars, i)
          i += run.length
          result.concat(shape_arabic_run(run))
        else
          result << chars[i]
          i += 1
        end
      end

      result.pack("U*")
    end

    # Shape Arabic text for PDF rendering.
    # Only converts characters to presentation forms (connected glyphs).
    # Text direction is handled by Prawn's align: :right for RTL locales.
    def process(text)
      return text if text.blank?

      shape(text)
    end

    private

    def collect_arabic_run(chars, start_index)
      run = []
      i = start_index
      while i < chars.length && (arabic_letter?(chars[i]) || arabic_mark?(chars[i]) || chars[i] == 0x0640)
        run << chars[i]
        i += 1
      end
      run
    end

    def arabic_letter?(codepoint)
      ARABIC_FORMS.key?(codepoint)
    end

    def arabic_mark?(codepoint)
      ARABIC_MARKS_SET.include?(codepoint)
    end

    def dual_joining?(codepoint)
      forms = ARABIC_FORMS[codepoint]
      return false if forms.nil?

      # Dual-joining if it has initial and medial forms
      forms[2] && forms[3]
    end

    def right_joining?(codepoint)
      forms = ARABIC_FORMS[codepoint]
      return false if forms.nil?

      # Right-joining only: has final form but no initial/medial
      forms[1] && !forms[2]
    end

    def join_causing?(codepoint)
      codepoint == 0x0640 || codepoint == 0x200D # TATWEEL or ZWJ
    end

    def can_join_to_right?(codepoint)
      dual_joining?(codepoint) || right_joining?(codepoint) || join_causing?(codepoint)
    end

    def can_join_to_left?(codepoint)
      dual_joining?(codepoint) || join_causing?(codepoint)
    end

    def shape_arabic_run(run)
      # Separate base characters and marks
      bases = []
      marks_map = {} # index => [marks]

      base_index = -1
      run.each do |cp|
        if arabic_mark?(cp)
          marks_map[base_index] ||= []
          marks_map[base_index] << cp
        else
          base_index += 1
          bases << cp
        end
      end

      # Handle Lam-Alef ligatures first
      shaped_bases = apply_lam_alef_ligatures(bases)

      # Determine joining context and select presentation forms
      result = []
      shaped_bases.each_with_index do |entry, idx|
        if entry.is_a?(Array)
          # Lam-Alef ligature [ligature_cp, :isolated/:final]
          ligature_cp = entry[0]
          result << ligature_cp
        else
          cp = entry
          forms = ARABIC_FORMS[codepoint]
          if forms
            prev_joins = idx > 0 && previous_can_join_left?(shaped_bases, idx)
            next_joins = idx < shaped_bases.length - 1 && next_can_join_right?(shaped_bases, idx)

            form = select_form(forms, prev_joins, next_joins)
            result << form
          else
            result << cp
          end
        end

        # Append any marks that belonged to this base character position
        original_idx = find_original_index(bases, shaped_bases, idx)
        if marks_map[original_idx]
          result.concat(marks_map[original_idx])
        end
      end

      result
    end

    def apply_lam_alef_ligatures(bases)
      result = []
      i = 0
      while i < bases.length
        if bases[i] == 0x0644 && i + 1 < bases.length && LAM_ALEF_LIGATURES.key?(bases[i + 1])
          alef = bases[i + 1]
          ligature_forms = LAM_ALEF_LIGATURES[alef]

          # Determine if lam had a connection from the right (previous char)
          prev_joins = i > 0 && can_join_to_left?(bases[i - 1])

          ligature_cp = prev_joins ? ligature_forms[1] : ligature_forms[0]
          result << [ligature_cp, prev_joins ? :final : :isolated]
          i += 2
        else
          result << bases[i]
          i += 1
        end
      end
      result
    end

    def previous_can_join_left?(shaped_bases, idx)
      prev = idx - 1
      while prev >= 0
        entry = shaped_bases[prev]
        if entry.is_a?(Array)
          # Lam-Alef ligature: can never join to the left (it consumed both lam+alef)
          return false
        end
        return can_join_to_left?(entry)
      end
      false
    end

    def next_can_join_right?(shaped_bases, idx)
      nxt = idx + 1
      while nxt < shaped_bases.length
        entry = shaped_bases[nxt]
        if entry.is_a?(Array)
          # Lam-Alef ligature always joins to the right (lam is dual-joining)
          return true
        end
        return can_join_to_right?(entry)
      end
      false
    end

    def find_original_index(bases, shaped_bases, shaped_idx)
      # Map back from shaped index to original base index
      orig = 0
      shaped = 0
      while shaped < shaped_idx && orig < bases.length
        if shaped_bases[shaped].is_a?(Array)
          orig += 2 # ligature consumed 2 base chars
        else
          orig += 1
        end
        shaped += 1
      end
      orig
    end

    def select_form(forms, prev_joins, next_joins)
      # forms = [isolated, final, initial, medial]
      if prev_joins && next_joins && forms[3]
        forms[3] # medial
      elsif prev_joins && forms[1]
        forms[1] # final
      elsif next_joins && forms[2]
        forms[2] # initial
      else
        forms[0] # isolated
      end
    end

  end
end

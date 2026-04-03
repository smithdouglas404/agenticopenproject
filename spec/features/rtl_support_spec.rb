# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RTL language support", :js do
  let(:user) { create(:admin, language: "ar") }

  before do
    login_as(user)
  end

  it "sets dir=rtl on html element for Arabic locale" do
    visit root_path
    expect(page).to have_css('html[dir="rtl"]')
  end

  it "sets dir=ltr for English locale" do
    user.update!(language: "en")
    visit root_path
    expect(page).to have_css('html[dir="ltr"]')
  end
end

# frozen_string_literal: true

#-- copyright
#++

require "spec_helper"
require "contracts/shared/model_contract_shared_context"
require_module_spec_helper

module Wikis
  module PageLinks
    RSpec.describe CreateContract do
      include_context "ModelContract shared context"
      let(:linkable) { create(:work_package) }
      let(:project) { linkable.project }
      let(:current_user) { create(:user, member_with_permissions: { project => %i(manage_wiki_page_links view_work_packages) }) }
      let(:relation_page_link) { build_stubbed(:relation_wiki_page_link, author: current_user, linkable:) }

      subject(:contract) { described_class.new(relation_page_link, current_user) }

      it_behaves_like "contract is valid"

      context "when creator is not the current user" do
        let(:author) { create(:user, member_with_permissions: { project => %i(manage_wiki_page_links view_work_packages) }) }
        let(:relation_page_link) { build_stubbed(:relation_wiki_page_link, author:, linkable:) }

        include_examples "contract is invalid", author: :invalid
      end

      context "when the provider is inexistent" do
        let(:provider) { InexistentProvider.new }

        before { relation_page_link.provider = provider }

        include_examples "contract is invalid", provider: :does_not_exist
      end
    end
  end
end

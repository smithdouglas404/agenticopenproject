module ::Grids
  class BaseInProjectController < ::ApplicationController
    before_action :find_optional_project

    def show
      render
    end
  end
end

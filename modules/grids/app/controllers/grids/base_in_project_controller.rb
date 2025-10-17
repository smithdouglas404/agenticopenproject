module ::Grids
  class BaseInProjectController < ::ApplicationController
    before_action :find_optional_project
    before_action :authorize

    def show
      render
    end
  end
end

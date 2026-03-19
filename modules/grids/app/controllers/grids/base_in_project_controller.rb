module ::Grids
  class BaseInProjectController < ::ApplicationController
    before_action :find_project_by_project_id
    before_action :authorize
    redirect_historical_project_identifier param_key: :project_id

    def show
      render
    end
  end
end

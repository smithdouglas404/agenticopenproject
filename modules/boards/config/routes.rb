Rails.application.routes.draw do
  extend Routing::Helpers::ProjectScope

  resources :boards,
            controller: "boards/boards",
            only: %i[index new create destroy],
            as: :work_package_boards

  project_scope do
    resources :boards,
              controller: "boards/boards",
              only: %i[index show new create],
              as: :work_package_boards do
      collection do
        get "menu" => "boards/menus#show"
      end
      get "(/*state)" => "boards/boards#show", on: :member, as: "", constraints: { id: /\d+/ }
    end
  end
end

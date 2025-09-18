# frozen_string_literal: true

Rails.application.routes.draw do
  constraints(Constraints::ProjectIdentifier) do
    scope "projects/:project_id", as: "project" do
      scope module: "overviews" do
        resource :overview, path: "/", only: [:show]

        controller :overviews do
          get "project_custom_fields_sidebar" => :project_custom_fields_sidebar, as: :custom_fields_sidebar
          get "project_life_cycle_sidebar" => :project_life_cycle_sidebar, as: :life_cycle_sidebar
        end

        resources :project_custom_field_sections, only: [:update], as: :custom_field_sections do
          get :show_dialog, on: :member
        end

        namespace :widgets do
          resource :project_status, only: %i[show update]
        end
      end
    end
  end

  resources :project_phases, controller: "overviews/project_phases", only: %i[edit update] do
    put :preview, on: :member
  end
end

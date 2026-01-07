# frozen_string_literal: true

class Types::UserType < Types::BaseObject
  field :id, ID, null: false
  field :email, String, null: false
  field :name, String, null: true
end

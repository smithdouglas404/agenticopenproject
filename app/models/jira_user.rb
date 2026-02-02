class JiraUser < ApplicationRecord
  belongs_to :jira
  belongs_to :jira_import

  def self.groups
    all.map { |x| x.payload["groups"]["items"] }.flatten.uniq {|x| x["name"]}
  end

  def to_op_attributes
    firstname = payload["displayName"].split(" ")[0..-2].join(" ")
    lastname = payload["displayName"].split(" ")[-1]
    {
      login: payload["name"],
      password: SecureRandom.uuid,
      firstname:,
      lastname:,
      mail: payload["emailAddress"],
      status: payload["active"] ? :active : :locked
    }
  end
end

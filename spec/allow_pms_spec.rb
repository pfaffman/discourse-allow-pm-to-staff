# frozen_string_literal: true

require "rails_helper"

describe TopicCreator do
  fab!(:user0) { Fabricate(:user, trust_level: TrustLevel[0]) }
  fab!(:normal_user) do
    Fabricate(:user, trust_level: TrustLevel[1], admin: false, moderator: false)
  end
  fab!(:group)
  fab!(:user2) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:admin)
  fab!(:moderator)

  let(:pm_valid_attrs_to_admin) do
    {
      raw: "this is a new post to a regular user",
      title: "this is a new title",
      archetype: Archetype.private_message,
      target_usernames: admin.username,
    }
  end
  let(:pm_to_moderator) do
    {
      raw: "this is a new post to a moderator",
      title: "this is a new title",
      archetype: Archetype.private_message,
      target_usernames: moderator.username,
    }
  end
  let(:pm_to_normal_user) do
    {
      raw: "this is another new post",
      title: "this is still a new title",
      archetype: Archetype.private_message,
      target_usernames: normal_user.username,
    }
  end

  context "when sending a personal message" do
    it "should be possible for a trusted user to send private message" do
      SiteSetting.personal_message_enabled_groups = group.id
      GroupUser.create(user: user2, group: group)
      expect(TopicCreator.create(user2, Guardian.new(user2), pm_to_normal_user)).to be_valid
    end

    it "should be possible for a new user to send private message to admin" do
      SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:staff]
      expect(TopicCreator.create(user0, Guardian.new(user0), pm_valid_attrs_to_admin)).to be_valid
    end

    it "should not be possible for a new user to send private message to normal user" do
      # staff = Group.find_by(name: "staff")
      SiteSetting.personal_message_enabled_groups = group.id
      expect do
        TopicCreator.create(user0, Guardian.new(normal_user), pm_to_normal_user)
      end.to raise_error(ActiveRecord::Rollback)
    end
    # it "can read a group page" do
    #   get "/g/admins.json"
    #   expect(response.status).to eq(200)
    # end
  end
end

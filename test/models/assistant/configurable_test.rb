require "test_helper"

class AssistantConfigurableTest < ActiveSupport::TestCase
  ISA_FUNCTIONS = [
    Assistant::Function::GetMyAccount,
    Assistant::Function::GetISATransactions
  ].freeze

  test "returns dashboard configuration by default" do
    chat = chats(:one)

    config = Assistant.config_for(chat)

    assert_not_empty config[:functions]
    assert_includes config[:instructions], "You help students navigate their financial journey"
  end

  test "returns intro configuration with search function only for unverified users" do
    chat = chats(:intro)

    config = Assistant.config_for(chat)

    assert_equal [ Assistant::Function::SearchFamilyFiles ], config[:functions]
    assert_includes config[:instructions], "Income Share Agreements"
  end

  test "dashboard configuration withholds ISA functions from unverified users" do
    config = Assistant.config_for(chats(:one))

    ISA_FUNCTIONS.each { |fn| assert_not_includes config[:functions], fn }
  end

  test "intro configuration includes ISA functions for verified users" do
    user = users(:sso_only)
    user.update_column(:ui_layout, "intro")
    chat = Chat.create!(user: user, title: "Verified intro chat")

    config = Assistant.config_for(chat)

    assert_equal [ Assistant::Function::SearchFamilyFiles, *ISA_FUNCTIONS ], config[:functions]
  end

  test "dashboard configuration includes ISA functions for verified users" do
    user = users(:sso_only)
    user.update_column(:ui_layout, "dashboard")
    chat = Chat.create!(user: user, title: "Verified dashboard chat")

    config = Assistant.config_for(chat)

    ISA_FUNCTIONS.each { |fn| assert_includes config[:functions], fn }
  end
end

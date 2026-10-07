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
    user = users(:unverified)
    user.update_column(:ui_layout, "intro")
    chat = Chat.create!(user: user, title: "Unverified intro chat")

    config = Assistant.config_for(chat)

    assert_equal [ Assistant::Function::SearchFamilyFiles ], config[:functions]
    assert_includes config[:instructions], "Income Share Agreements"
  end

  test "dashboard configuration withholds ISA functions from unverified users" do
    user = users(:unverified)
    user.update_column(:ui_layout, "dashboard")
    config = Assistant.config_for(Chat.create!(user: user, title: "Unverified dashboard chat"))

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

  test "unverified users keep the assistant but get no data tools" do
    user = users(:unverified)
    chat = Chat.create!(user: user, title: "Unverified chat")

    config = Assistant.config_for(chat)

    assert_equal [ Assistant::Function::SearchFamilyFiles ], config[:functions]
  end
  test "escalation and ISA guidance follow the member's country" do
    chat = chats(:intro)
    chat.user.update!(country_code: "RW")

    instructions = Assistant.config_for(chat)[:instructions]

    assert_includes instructions, "Chancen Rwanda team"
    assert_includes instructions, "Use the rwanda ISA content source"
    assert_not_includes instructions, "Always refer to the 'Chancen Kenya team'"
  end

  test "neutral guidance when the member has no country" do
    chat = chats(:intro)
    chat.user.update!(country_code: nil)

    instructions = Assistant.config_for(chat)[:instructions]

    assert_includes instructions, "the Chancen team"
    assert_includes instructions, "do not default to Kenya or any other country-specific team"
  end
end

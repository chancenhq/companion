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
    assert_includes instructions, "Do not default to Kenya"
  end
end

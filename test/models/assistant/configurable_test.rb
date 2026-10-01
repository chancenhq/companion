require "test_helper"

class AssistantConfigurableTest < ActiveSupport::TestCase
  test "returns dashboard configuration by default" do
    chat = chats(:one)

    config = Assistant.config_for(chat)

    assert_not_empty config[:functions]
    assert_includes config[:instructions], "You help students navigate their financial journey"
  end

  test "returns intro configuration with search functions only" do
    chat = chats(:intro)

    config = Assistant.config_for(chat)

    assert_equal [ Assistant::Function::SearchFamilyFiles ], config[:functions]
    assert_includes config[:instructions], "Income Share Agreements"
  end

  test "uses confirmed country for escalation guidance" do
    chat = chats(:intro)
    chat.user.update!(country_code: "RW")

    config = Assistant.config_for(chat)

    assert_includes config[:instructions], "Chancen Rwanda team"
    assert_includes config[:instructions], "support.rw@chancen.org"
    assert_includes config[:instructions], "Use the rwanda ISA content source"
    assert_includes config[:instructions], "include rwanda and Rwanda in the search query"
    refute_includes config[:instructions], "Always refer to the 'Chancen Kenya team'"
  end

  test "uses neutral escalation guidance when country is missing" do
    chat = chats(:intro)
    chat.user.update!(country_code: nil)

    config = Assistant.config_for(chat)

    assert_includes config[:instructions], "the Chancen team"
    assert_includes config[:instructions], "Do not default to Kenya"
  end
end

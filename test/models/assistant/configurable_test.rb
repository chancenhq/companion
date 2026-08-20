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
end

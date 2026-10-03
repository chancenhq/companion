module Assistant
  Error = Class.new(StandardError)

  REGISTRY = {
    "builtin" => Assistant::Builtin,
    "external" => Assistant::External
  }.freeze

  class << self
    def for_chat(chat)
      implementation_for(chat).for_chat(chat)
    end

    def config_for(chat)
      raise Error, "chat is required" if chat.blank?
      Assistant::Builtin.config_for(chat)
    end

    def available_types
      REGISTRY.keys
    end

    def function_classes
      [
        Function::GetTransactions,
        Function::GetAccounts,
        Function::GetHoldings,
        Function::GetBalanceSheet,
        Function::GetIncomeStatement,
        Function::ImportBankStatement,
        Function::SearchFamilyFiles,
        Function::GetMyAccount,
        Function::GetISATransactions
      ]
    end

    # Functions that read Chancen Account (ISA) data, looked up by email.
    def isa_function_classes
      [ Function::GetMyAccount, Function::GetISATransactions ]
    end

    # Function classes this user may use: ISA functions need a verified email
    # (issue #106, Story 3.2). Used by the assistant config and MCP.
    def function_classes_for(user)
      return function_classes if user.email_verified?

      function_classes - isa_function_classes
    end

    private

      def implementation_for(chat)
        raise Error, "chat is required" if chat.blank?
        type = ENV["ASSISTANT_TYPE"].presence || chat.user&.family&.assistant_type.presence || "builtin"
        REGISTRY.fetch(type) { REGISTRY["builtin"] }
      end
  end
end

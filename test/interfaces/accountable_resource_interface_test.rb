require "test_helper"

module AccountableResourceInterfaceTest
  extend ActiveSupport::Testing::Declarative

  test "shows new form" do
    ensure_tailwind_build
    Family.any_instance.stubs(:get_link_token).returns("test-link-token")

    get new_polymorphic_url(@account.accountable)
    assert_response :success
  end

  test "shows edit form" do
    ensure_tailwind_build

    get edit_account_url(@account)
    assert_response :success
  end

  test "update saves currency change" do
    @account.update!(currency: "USD")

    patch send("#{@account.accountable_type.underscore}_path", @account), params: {
      account: {
        name: @account.name,
        currency: "EUR"
      }
    }

    @account.reload
    assert_equal "EUR", @account.currency
  end

  test "edit form shows account metadata field" do
    ensure_tailwind_build
    @account.update!(metadata: { "external_id" => "acct_123" })

    get edit_account_url(@account)

    assert_response :success
    assert_select "textarea[name='account[metadata]']", text: /external_id/
  end

  test "update saves metadata from JSON object field" do
    patch send("#{@account.accountable_type.underscore}_path", @account), params: {
      account: {
        name: @account.name,
        metadata: JSON.dump({ external_id: "acct_123", source: "manual" })
      }
    }

    if @account.active? && @account.property?
      assert_response :success
    else
      assert_redirected_to account_path(@account)
    end
    assert_equal({ "external_id" => "acct_123", "source" => "manual" }, @account.reload.metadata)
  end

  test "update rejects invalid metadata JSON" do
    ensure_tailwind_build
    original_metadata = { "external_id" => "acct_123" }
    @account.update!(metadata: original_metadata)

    patch send("#{@account.accountable_type.underscore}_path", @account), params: {
      account: {
        name: @account.name,
        metadata: "not-json"
      }
    }

    assert_response :unprocessable_entity
    assert_equal original_metadata, @account.reload.metadata
    assert_includes response.body, I18n.t("accounts.form.invalid_metadata_json")
  end

  test "update rejects metadata JSON that is not an object" do
    ensure_tailwind_build
    original_metadata = { "external_id" => "acct_123" }
    @account.update!(metadata: original_metadata)

    patch send("#{@account.accountable_type.underscore}_path", @account), params: {
      account: {
        name: @account.name,
        metadata: JSON.dump([ "not", "an", "object" ])
      }
    }

    assert_response :unprocessable_entity
    assert_equal original_metadata, @account.reload.metadata
    assert_includes response.body, I18n.t("accounts.form.invalid_metadata_json")
  end
end

require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    ensure_tailwind_build
    sign_in users(:sure_support_staff)
  end

  test "index groups users by family sorted by transaction count" do
    family_with_more = users(:family_admin).family
    family_with_fewer = users(:empty).family

    account = Account.create!(family: family_with_more, name: "Test", balance: 0, currency: "USD", accountable: Depository.new)
    3.times { |i| account.entries.create!(name: "Txn #{i}", date: Date.current, amount: 10, currency: "USD", entryable: Transaction.new) }

    get admin_users_url
    assert_response :success

    body = response.body
    more_idx = body.index(family_with_more.name)
    fewer_idx = body.index(family_with_fewer.name)

    assert_not_nil more_idx
    assert_not_nil fewer_idx
    assert_operator more_idx, :<, fewer_idx,
      "Family with more transactions should appear before family with fewer"
  end

  test "index shows subscription status for families" do
    family = users(:family_admin).family
    family.subscription&.destroy
    Subscription.create!(
      family_id: family.id,
      status: :active,
      stripe_id: "cus_test_#{family.id}"
    )

    get admin_users_url
    assert_response :success
    assert_match(/Active/, response.body, "Page should show subscription status for families with active subscriptions")
  end

  test "index shows no subscription label for families without subscription" do
    users(:family_admin).family.subscription&.destroy

    get admin_users_url
    assert_response :success
    assert_match(/No subscription/, response.body, "Page should show 'No subscription' for families without one")
  end

  test "index sorts family users by role priority then first name" do
    family = users(:family_admin).family

    zach = create_admin_user(family:, first_name: "Zach", role: "super_admin")
    amy = create_admin_user(family:, first_name: "Amy", role: "super_admin")
    charlie = create_admin_user(family:, first_name: "Charlie", role: "admin")
    betty = create_admin_user(family:, first_name: "Betty", role: "member")
    aaron = create_admin_user(family:, first_name: "Aaron", role: "guest")

    get admin_users_url
    assert_response :success

    document = Nokogiri::HTML(response.body)
    section_emails = document.css("[data-admin-role-section]").flat_map do |section|
      section.css("[data-admin-user-email]").map { |row| row["data-admin-user-email"] }
    end

    expected_order = [ amy, zach, users(:family_admin), charlie, betty, users(:family_member), aaron ].map(&:email)
    assert_equal expected_order, section_emails & expected_order
  end

  test "index sorts pending invitations by role priority then email" do
    family = users(:family_admin).family
    member_invite = invitations(:one)
    admin_invite = invitations(:two)
    guest_invite = create_invitation(family:, email: "guest-sort@example.com", role: "guest")
    earlier_admin_invite = create_invitation(family:, email: "aaa-admin-sort@example.com", role: "admin")

    get admin_users_url
    assert_response :success

    document = Nokogiri::HTML(response.body)
    invitation_emails = document.css("[data-admin-invitation-role-section]").flat_map do |section|
      section.css("[data-admin-invitation-email]").map { |row| row["data-admin-invitation-email"] }
    end

    expected_order = [ earlier_admin_invite, admin_invite, member_invite, guest_invite ].map(&:email)
    assert_equal expected_order, invitation_emails & expected_order
  end

  private
    def create_admin_user(family:, first_name:, role:)
      family.users.create!(
        first_name: first_name,
        last_name: "Sort",
        email: "#{first_name.downcase}-#{role}-sort@example.com",
        password: user_password_test,
        role: role,
        onboarded_at: Time.current,
        ui_layout: "dashboard"
      )
    end

    def create_invitation(family:, email:, role:)
      family.invitations.create!(
        email: email,
        role: role,
        inviter: users(:family_admin)
      )
    end
end

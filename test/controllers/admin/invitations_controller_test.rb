require "test_helper"

class Admin::InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:sure_support_staff)
    sign_in @admin
  end

  test "destroy all only deletes pending invitations for requested role" do
    family = users(:family_admin).family
    admin_invite = invitations(:two)
    assert_equal "admin", admin_invite.role, "Fixture setup: invitations(:two) must be admin role"
    member_invite = invitations(:one)
    assert_equal "member", member_invite.role, "Fixture setup: invitations(:one) must be member role"
    guest_invite = family.invitations.create!(
      email: "role-delete-guest@example.com",
      role: "guest",
      inviter: users(:family_admin)
    )

    assert_difference -> { Invitation.pending.where(family: family, role: "admin").count }, -1 do
      assert_no_difference -> { Invitation.pending.where(family: family, role: "member").count } do
        assert_no_difference -> { Invitation.pending.where(family: family, role: "guest").count } do
          delete invitations_admin_family_url(family, role: "admin")
        end
      end
    end

    assert_redirected_to admin_users_url
    assert_not Invitation.exists?(admin_invite.id)
    assert Invitation.exists?(member_invite.id)
    assert Invitation.exists?(guest_invite.id)
  end
end

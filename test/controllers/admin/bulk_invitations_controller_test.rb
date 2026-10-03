require "test_helper"

class Admin::BulkInvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ensure_tailwind_build
    sign_in users(:sure_support_staff)
    @family = families(:empty)
  end

  test "reserves a place for each new email without sending anything" do
    assert_no_enqueued_emails do
      assert_difference "Invitation.count", 2 do
        post admin_bulk_invitations_path, params: { family_id: @family.id, emails: "a@example.com, b@example.com" }
      end
    end

    assert_response :success
    assert_includes response.body, "Place reserved"
    invitation = Invitation.find_by!(email: "a@example.com")
    assert_equal @family, invitation.family
    assert invitation.pending?
    assert_equal "private", @family.reload.default_account_sharing
  end

  test "leaves students who already have an account where they are by default" do
    student = users(:family_member)

    assert_no_difference "Invitation.count" do
      post admin_bulk_invitations_path, params: { family_id: @family.id, emails: student.email }
    end

    assert_includes response.body, "not moved"
    assert_not_equal @family, student.reload.family
  end

  test "moves existing accounts only when the admin asks for it" do
    student = users(:family_member)

    post admin_bulk_invitations_path, params: { family_id: @family.id, emails: student.email, move_existing: "1" }

    assert_includes response.body, "moved to this family"
    assert_equal @family, student.reload.family
  end

  test "asks for at least one email" do
    post admin_bulk_invitations_path, params: { family_id: @family.id, emails: " " }

    assert_response :unprocessable_entity
  end
end

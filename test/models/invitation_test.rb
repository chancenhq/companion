require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  setup do
    @invitation = invitations(:one)
    @family = @invitation.family
    @inviter = @invitation.inviter
  end

  test "cannot invite the inviter's own email" do
    invitation = @family.invitations.build(email: @inviter.email.upcase, role: "member", inviter: @inviter)

    assert_not invitation.valid?
    assert invitation.errors.of_kind?(:email, :own_email)
  end

  test "cannot create invitation when email has pending invitation from another family" do
    other_family = families(:empty)
    other_inviter = users(:empty)
    other_inviter.update_columns(family_id: other_family.id, role: "admin")

    email = "cross-family-test@example.com"

    # Create a pending invitation in the first family
    @family.invitations.create!(email: email, role: "member", inviter: @inviter)

    # Attempting to create a pending invitation in a different family should fail
    invitation = other_family.invitations.build(email: email, role: "member", inviter: other_inviter)
    assert_not invitation.valid?
    assert_includes invitation.errors[:email], "already has a pending invitation from another family"
  end

  test "can create invitation when existing invitation from another family is accepted" do
    other_family = families(:empty)
    other_inviter = users(:empty)
    other_inviter.update_columns(family_id: other_family.id, role: "admin")

    email = "cross-family-accepted@example.com"

    # Create an accepted invitation in the first family
    accepted_invitation = @family.invitations.create!(email: email, role: "member", inviter: @inviter)
    accepted_invitation.update!(accepted_at: Time.current)

    # Should be able to create a pending invitation in a different family
    invitation = other_family.invitations.build(email: email, role: "member", inviter: other_inviter)
    assert invitation.valid?
  end

  test "can create invitation when existing invitation from another family is expired" do
    other_family = families(:empty)
    other_inviter = users(:empty)
    other_inviter.update_columns(family_id: other_family.id, role: "admin")

    email = "cross-family-expired@example.com"

    # Create an expired invitation in the first family
    expired_invitation = @family.invitations.create!(email: email, role: "member", inviter: @inviter)
    expired_invitation.update_columns(expires_at: 1.day.ago)

    # Should be able to create a pending invitation in a different family
    invitation = other_family.invitations.build(email: email, role: "member", inviter: other_inviter)
    assert invitation.valid?
  end

  test "re-inviting an email with an expired unaccepted invitation replaces it without raising" do
    email = "expired-reinvite@example.com"

    expired = @family.invitations.create!(email: email, role: "member", inviter: @inviter)
    expired.update_column(:expires_at, 1.day.ago)

    invitation = nil
    assert_nothing_raised do
      invitation = @family.invitations.create!(email: email, role: "admin", inviter: @inviter)
    end

    assert invitation.pending?
    assert_not Invitation.exists?(expired.id), "stale expired invitation should be removed"
    assert_equal 1, @family.invitations.where(email: email).count
  end

  test "re-invite does not remove a still-pending duplicate (validation blocks first)" do
    email = "still-pending@example.com"
    pending = @family.invitations.create!(email: email, role: "member", inviter: @inviter)

    duplicate = @family.invitations.build(email: email, role: "admin", inviter: @inviter)
    assert_not duplicate.valid?

    assert Invitation.exists?(pending.id), "an unexpired pending invitation must be preserved"
  end

  test "can create invitation in same family (uniqueness scoped to family)" do
    email = "same-family-test@example.com"

    # Create a pending invitation in the family
    @family.invitations.create!(email: email, role: "member", inviter: @inviter)

    # Attempting to create another in the same family should fail due to the existing scope validation
    invitation = @family.invitations.build(email: email, role: "admin", inviter: @inviter)
    assert_not invitation.valid?
    assert_includes invitation.errors[:email], "has already been invited to this family"
  end

  test "an email that already belongs to an account can be invited like any other" do
    invitation = @family.invitations.build(email: users(:empty).email, role: "member", inviter: @inviter)

    assert invitation.valid?
  end

  # Country (issue #106): members get theirs from the invitation.
  test "takes its country from the family" do
    @family.update!(chancen_country_code: "RW")

    invitation = @family.invitations.create!(email: "student@example.com", role: "member", inviter: @inviter)

    assert_equal "RW", invitation.country_code
  end

  test "cannot be created for a family without a country" do
    @family.update!(chancen_country_code: nil)

    invitation = @family.invitations.build(email: "student@example.com", role: "member", inviter: @inviter)

    assert_not invitation.valid?
    assert_includes invitation.errors[:base], I18n.t("activerecord.errors.models.invitation.attributes.base.family_country_missing")
  end

  test "accept_signup! marks the invitation accepted and gives the new user its country" do
    @invitation.update_column(:country_code, "GH")
    user = users(:empty)
    user.update!(country_code: nil)

    @invitation.accept_signup!(user)

    assert_not_nil @invitation.reload.accepted_at
    assert_equal "GH", user.reload.country_code
  end

  test "would_orphan_owned_accounts? is false when same-family role change" do
    user = users(:family_member)
    user.update!(family_id: @family.id, role: "member")
    invitation = @family.invitations.create!(email: user.email, role: "admin", inviter: @inviter)

    assert_not invitation.would_orphan_owned_accounts?(user)
  end

  test "accept_for applies guest role defaults" do
    user = users(:family_member)
    user.update!(
      family_id: @family.id,
      role: "member",
      ui_layout: "dashboard",
      show_sidebar: true,
      show_ai_sidebar: true,
      ai_enabled: false
    )
    invitation = @family.invitations.create!(email: user.email, role: "guest", inviter: @inviter)

    result = invitation.accept_for(user)

    assert result
    user.reload
    assert_equal "guest", user.role
    assert user.ui_layout_intro?
    assert_not user.show_sidebar?
    assert_not user.show_ai_sidebar?
    assert user.ai_enabled?
  end

  test "accept_for auto-shares existing family accounts when family shares by default" do
    @family.update!(default_account_sharing: "shared")
    user = users(:empty)
    user.update_columns(family_id: families(:empty).id, role: "admin")
    invitation = @family.invitations.create!(email: user.email, role: "member", inviter: @inviter)

    expected_ids = @family.accounts.where.not(owner_id: user.id).pluck(:id).sort
    assert expected_ids.any?

    assert invitation.accept_for(user)

    assert_equal expected_ids, AccountShare.where(user: user).pluck(:account_id).sort
  end

  test "accept_for auto-shares read_only for guest invitations" do
    @family.update!(default_account_sharing: "shared")
    user = users(:empty)
    user.update_columns(family_id: families(:empty).id, role: "admin")
    invitation = @family.invitations.create!(email: user.email, role: "guest", inviter: @inviter)

    expected_ids = @family.accounts.where.not(owner_id: user.id).pluck(:id).sort
    assert expected_ids.any?

    assert invitation.accept_for(user)

    user.reload
    shares = AccountShare.where(user: user)
    assert_equal "guest", user.role
    assert_equal expected_ids, shares.pluck(:account_id).sort
    assert shares.all?(&:read_only?), "guest invitation shares must grant read_only"
  end

  test "accept_for does not auto-share when family sharing is private" do
    @family.update!(default_account_sharing: "private")
    user = users(:empty)
    user.update_columns(family_id: families(:empty).id, role: "admin")
    invitation = @family.invitations.create!(email: user.email, role: "member", inviter: @inviter)

    assert_no_difference "AccountShare.count" do
      assert invitation.accept_for(user)
    end
  end

  test "accepting an invitation releases provider items left behind" do
    # The item's owner is leaving the family but the item stays. Without
    # releasing it, the orphaned owner fails ProviderItemOwnable's same-family
    # validation on the next save and the connection becomes unsyncable.
    user = users(:family_member)
    old_family = user.family
    item = PlaidItem.create!(
      family: old_family, plaid_id: "item_invite_#{SecureRandom.hex(4)}",
      access_token: "token", name: "Left Behind Bank", owner: user
    )
    new_family = Family.create!(name: "Invited Family", chancen_country_code: "KE")
    invitation = Invitation.create!(
      family: new_family, email: user.email, role: "member",
      inviter: users(:family_admin)
    )

    assert invitation.accept_for(user)

    assert_nil item.reload.owner_id
    assert_equal old_family, item.family
    assert item.valid?, "the left-behind item must still be savable"
  end
end

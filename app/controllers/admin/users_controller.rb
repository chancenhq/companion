# frozen_string_literal: true

module Admin
  class UsersController < Admin::BaseController
    before_action :set_user, only: %i[update]

    def index
      authorize User
      scope = policy_scope(User)
        .left_joins(family: :subscription)
        .includes(family: :subscription)

      scope = scope.where(role: params[:role]) if params[:role].present?
      scope = apply_trial_filter(scope) if params[:trial_status].present?

      users = scope.order(
        Arel.sql(
          "CASE " \
          "WHEN subscriptions.status = 'trialing' THEN 0 " \
          "WHEN subscriptions.id IS NULL THEN 1 " \
          "ELSE 2 END, " \
          "subscriptions.trial_ends_at ASC NULLS LAST, users.email ASC"
        )
      ).to_a

      users_by_family = users.group_by(&:family).transform_values do |family_users|
        family_users.sort_by(&:sort_key)
      end
      @user_sections_by_family = users_by_family.transform_values { |family_users| user_role_sections(family_users) }

      family_ids = users.map(&:family_id).uniq
      @accounts_count_by_family = Account.where(family_id: family_ids).group(:family_id).count
      @entries_count_by_family = Entry.joins(:account).where(accounts: { family_id: family_ids }).group("accounts.family_id").count

      user_ids = users.map(&:id).uniq
      @last_login_by_user = Session.where(user_id: user_ids).group(:user_id).maximum(:created_at)
      @sessions_count_by_user = Session.where(user_id: user_ids).group(:user_id).count

      @families_with_users = users_by_family.sort_by do |family, _users|
        -(@entries_count_by_family[family.id] || 0)
      end

      @invitations_by_family = Invitation.pending
        .where(family_id: family_ids)
        .to_a
        .group_by(&:family_id)
        .transform_values { |invitations| invitations.sort_by(&:sort_key) }
      @invitation_sections_by_family = @invitations_by_family.transform_values { |invitations| invitation_role_sections(invitations) }

      @trials_expiring_in_7_days = Subscription
        .where(status: :trialing)
        .where(trial_ends_at: Time.current..7.days.from_now)
        .count
    end

    def update
      authorize @user

      if @user.update(user_params)
        Rails.logger.info(
          "[Admin::Users] Role changed - " \
          "by_user_id=#{Current.user.id} " \
          "target_user_id=#{@user.id} " \
          "new_role=#{@user.role}"
        )
        redirect_to admin_users_path, notice: t(".success")
      else
        redirect_to admin_users_path, alert: t(".failure")
      end
    end

    private

      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        params.require(:user).permit(:role)
      end

      def user_role_sections(users)
        records_by_role(users).map do |role, role_users|
          {
            role: role,
            role_label: role_label(role),
            users: role_users
          }
        end
      end

      def invitation_role_sections(invitations)
        records_by_role(invitations).map do |role, role_invitations|
          role_label = role_label(role)

          {
            role: role,
            role_label: role_label,
            invitations: role_invitations.map do |invitation|
              {
                invitation: invitation,
                delete_confirm: invitation_delete_confirm(invitation)
              }
            end,
            delete_all_confirm: invitation_delete_all_confirm(role_label, role_invitations.size)
          }
        end
      end

      def records_by_role(records)
        grouped_records = records.group_by(&:role)

        User.role_order.filter_map do |role|
          role_records = grouped_records[role]
          [ role, role_records ] if role_records.present?
        end
      end

      def role_label(role)
        t("admin.users.index.roles.#{role}", default: role.to_s.humanize)
      end

      def invitation_delete_confirm(invitation)
        CustomConfirm.new(
          title: t("admin.users.index.invitations.delete_confirm_title", email: invitation.email),
          body: t("admin.users.index.invitations.delete_confirm_body"),
          btn_text: t("admin.users.index.invitations.delete"),
          destructive: true
        )
      end

      def invitation_delete_all_confirm(role_label, count)
        CustomConfirm.new(
          title: t("admin.users.index.invitations.delete_all_confirm_title", count: count, role: role_label),
          body: t("admin.users.index.invitations.delete_all_confirm_body", role: role_label),
          btn_text: t("admin.users.index.invitations.delete_all"),
          destructive: true,
          high_severity: true
        )
      end

      def apply_trial_filter(scope)
        case params[:trial_status]
        when "expiring_soon"
          scope.where(subscriptions: { status: :trialing })
            .where(subscriptions: { trial_ends_at: Time.current..7.days.from_now })
        when "trialing"
          scope.where(subscriptions: { status: :trialing })
        else
          scope
        end
      end
  end
end

# frozen_string_literal: true

module Admin
  class UsersController < Admin::BaseController
    ROLE_ORDER = %w[super_admin admin member guest].freeze

    before_action :set_user, only: %i[update]
    helper_method :admin_user_role_order

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
        family_users.sort_by { |user| user_sort_key(user) }
      end

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
        .transform_values { |invitations| invitations.sort_by { |invitation| invitation_sort_key(invitation) } }

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

      def admin_user_role_order
        ROLE_ORDER
      end

      def user_sort_key(user)
        [
          ROLE_ORDER.index(user.role) || ROLE_ORDER.length,
          (user.first_name.presence || user.display_name).to_s.downcase,
          user.last_name.to_s.downcase,
          user.email.to_s.downcase
        ]
      end

      def invitation_sort_key(invitation)
        [
          ROLE_ORDER.index(invitation.role) || ROLE_ORDER.length,
          invitation.email.to_s.downcase
        ]
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

class Invitation < ApplicationRecord
  include Encryptable

  belongs_to :family
  belongs_to :inviter, class_name: "User"

  # Encrypt sensitive fields if ActiveRecord encryption is configured
  if encryption_ready?
    encrypts :token, deterministic: true
    encrypts :email, deterministic: true, downcase: true
  end

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: %w[admin member guest] }
  validates :token, presence: true, uniqueness: true
  validate :no_duplicate_pending_invitation_in_family
  validate :inviter_is_admin, on: :create
  validate :no_other_pending_invitation, on: :create
  validate :family_has_country, on: :create
  validate :not_inviting_self, on: :create

  before_validation :normalize_email
  before_validation :set_country_from_family, on: :create
  before_validation :generate_token, on: :create
  before_create :remove_expired_duplicates_in_family
  before_create :set_expiration

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :accepted, -> { where.not(accepted_at: nil) }

  def pending?
    accepted_at.nil? && expires_at > Time.current
  end

  # Whether the invitation (and its token) was emailed to the invitee.
  def emailed?
    email_sent_at.present?
  end

  # A seat reserved for this email that was never emailed (e.g. bulk
  # invite), so an email sign-up can claim it without a token.
  # An emailed invitation needs its token: its address may belong to an
  # existing household's invitee, and the email alone proves nothing.
  def self.seat_for(email)
    return if email.blank?

    pending.where(email_sent_at: nil).find_by(email: email.to_s.strip.downcase)
  end

  # Marks the invitation used by a newly created account and gives that
  # account the invitation's country.
  def accept_signup!(user)
    update!(accepted_at: Time.current)
    user.record_country!(country_code) if country_code.present?
    # A new account joining via invitation must honor the family's default
    # sharing policy. The method
    # is guarded by a same-family membership check, so it no-ops safely when the
    # user is not (yet) a member of this invitation's family.
    family.auto_share_existing_accounts_with(user)
  end

  private

    def generate_token
      loop do
        self.token = SecureRandom.hex(32)
        break unless self.class.exists?(token: token)
      end
    end

    def set_expiration
      self.expires_at = 3.days.from_now
    end

    # An expired, never-accepted invitation still occupies the partial unique
    # index `index_invitations_on_email_and_family_id_pending` (predicate
    # `accepted_at IS NULL`), but the `pending` scope treats it as gone because
    # of the `expires_at > now` clause. The duplicate-guard validation therefore
    # passes, and the INSERT collides with the index, raising RecordNotUnique.
    # Removing the stale row inside the create transaction frees the slot so the
    # re-invite can proceed. It runs only after validations pass, so a still
    # pending (non-expired) invitation can never be removed here.
    def remove_expired_duplicates_in_family
      return if email.blank?

      scope = self.class.where(family_id: family_id, accepted_at: nil)
                        .where("expires_at <= ?", Time.current)

      scope = if self.class.encryption_ready?
        scope.where(email: email)
      else
        scope.where("LOWER(email) = ?", email.to_s.strip.downcase)
      end

      scope.delete_all
    end

    def normalize_email
      self.email = email.to_s.strip.downcase if email.present?
    end

    def set_country_from_family
      self.country_code = family&.chancen_country_code
    end

    # Members get their country from the invitation, so it must carry one.
    def family_has_country
      errors.add(:base, :family_country_missing) if country_code.blank?
    end

    def no_other_pending_invitation
      return if email.blank?

      existing = if self.class.encryption_ready?
        self.class.pending.where(email: email).where.not(family_id: family_id).exists?
      else
        self.class.pending.where("LOWER(email) = ?", email.downcase).where.not(family_id: family_id).exists?
      end

      if existing
        errors.add(:email, "already has a pending invitation from another family")
      end
    end

    def no_duplicate_pending_invitation_in_family
      return if email.blank?

      scope = self.class.pending.where(family_id: family_id)
      scope = scope.where.not(id: id) if persisted?

      exists = if self.class.encryption_ready?
        scope.where(email: email).exists?
      else
        scope.where("LOWER(email) = ?", email.to_s.strip.downcase).exists?
      end

      errors.add(:email, "has already been invited to this family") if exists
    end

    # The inviter already has an account, and an invitation never moves one.
    def not_inviting_self
      return if email.blank? || inviter.nil?

      errors.add(:email, :own_email) if email == inviter.email.to_s.strip.downcase
    end

    def inviter_is_admin
      errors.add(:inviter, "must be an admin") unless inviter&.admin? || inviter&.super_admin?
    end
end

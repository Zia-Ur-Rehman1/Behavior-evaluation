class User < ApplicationRecord
  has_secure_password

  enum role: { viewer: 0, editor: 1, admin: 2 }

  validates :name,  presence: true
  validates :email, presence: true, uniqueness: true,
                    format: { with: /\A[^@\s]+@[^@\s]+\z/ }
  validates :role,  presence: true

  after_initialize :set_default_role, if: :new_record?

  def can_use_mcp?
    admin? || editor?
  end

  def can_manage_users?
    admin?
  end

  private

  def set_default_role
    self.role ||= :viewer
  end
end

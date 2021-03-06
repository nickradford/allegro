class User < ActiveRecord::Base
  belongs_to :performer
  has_many :user_oauth2_accounts
  has_many :scraper_credentials, dependent: :delete_all

  # TODO(nharper): Rewrite these. I'm ok with users not belonging to a
  # performer; e.g. role account or staff. I probably want to validate that
  # performer_id is unique if present (but multiple NULLs are allowed).
  # validates :performer_id, :presence => true
  # validates :performer_id, :uniqueness => true

  def fill_login_token
    # Replace '+' and '/' in the base64 encoding with '-' and '_' to use the url
    # and filename safe alphabet from RFC 4648.
    self.login_token = SecureRandom.base64(30).gsub('+', '-').gsub('/', '_')
  end

  def fill_login_token_and_save
    self.fill_login_token
    self.save!
  end

  def clear_login_token
    self.login_token = nil
    self.save!
  end

  def self.find_by_login_token(token)
    return nil unless token.length == 40
    return User.where(:login_token => token).first
  end
end

class User < ActiveRecord::Base
  belongs_to :performer
  has_many :user_oauth2_accounts

  validates :performer_id, :presence => true
  validates :performer_id, :uniqueness => true

  def fill_login_token
    self.login_token = SecureRandom.base64(30)
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

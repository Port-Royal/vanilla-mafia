class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    unless auth
      redirect_to new_user_session_path, alert: I18n.t("devise.omniauth_callbacks.failure", kind: "Google", reason: "invalid")
      return
    end

    user = find_or_create_user

    if user
      sign_in_and_redirect user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
    else
      redirect_to new_user_session_path, alert: I18n.t("devise.omniauth_callbacks.failure", kind: "Google", reason: "invalid")
    end
  end

  def failure
    redirect_to new_user_session_path, alert: I18n.t("devise.omniauth_callbacks.failure", kind: "Google", reason: failure_message)
  end

  private

  def auth
    request.env["omniauth.auth"]
  end

  def email_verified?
    auth.dig(:extra, :raw_info, :email_verified) != false
  end

  def normalized_email
    auth.info.email.to_s.strip.downcase
  end

  def find_or_create_user
    user = User.find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    return unless email_verified?

    email = normalized_email
    return if email.blank?

    user = User.find_by(email: email)
    if user
      user.update(provider: auth.provider, uid: auth.uid)
      return user
    end

    User.create(
      provider: auth.provider,
      uid: auth.uid,
      email: email,
      password: Devise.friendly_token(32)
    )
  rescue ActiveRecord::RecordNotUnique
    User.find_by(provider: auth.provider, uid: auth.uid)
  end
end

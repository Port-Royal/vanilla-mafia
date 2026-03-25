class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    user = find_or_create_user(auth)

    if user.persisted?
      sign_in_and_redirect user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
    else
      redirect_to new_user_session_path, alert: user.errors.full_messages.join(", ")
    end
  end

  def failure
    redirect_to new_user_session_path, alert: I18n.t("devise.omniauth_callbacks.failure", kind: "Google", reason: failure_message)
  end

  private

  def auth
    request.env["omniauth.auth"]
  end

  def find_or_create_user(auth)
    user = User.find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    user = User.find_by(email: auth.info.email)
    if user
      user.update!(provider: auth.provider, uid: auth.uid)
      return user
    end

    User.create!(
      provider: auth.provider,
      uid: auth.uid,
      email: auth.info.email,
      password: Devise.friendly_token(32)
    )
  end
end

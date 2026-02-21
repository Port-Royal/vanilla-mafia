require "rails_helper"

RSpec.describe ErrorsController do
  around do |example|
    env = Rails.application.env_config
    original_show = env["action_dispatch.show_exceptions"]
    original_local = env["action_dispatch.show_detailed_exceptions"]
    env["action_dispatch.show_exceptions"] = :all
    env["action_dispatch.show_detailed_exceptions"] = false
    example.run
  ensure
    env["action_dispatch.show_exceptions"] = original_show
    env["action_dispatch.show_detailed_exceptions"] = original_local
  end

  describe "GET /404" do
    before { get "/404" }

    it "returns 404 status" do
      expect(response).to have_http_status(:not_found)
    end

    it "renders the error title" do
      expect(response.body).to include("Страница не найдена")
    end

    it "renders a link to the home page" do
      expect(response.body).to include("На главную")
    end
  end

  describe "GET /422" do
    before { get "/422" }

    it "returns 422 status" do
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "renders the error title" do
      expect(response.body).to include("Действие невозможно")
    end

    it "renders a link to the home page" do
      expect(response.body).to include("На главную")
    end
  end

  describe "GET /500" do
    before { get "/500" }

    it "returns 500 status" do
      expect(response).to have_http_status(:internal_server_error)
    end

    it "renders the error title" do
      expect(response.body).to include("Ошибка сервера")
    end

    it "renders a link to the home page" do
      expect(response.body).to include("На главную")
    end
  end

  describe "GET /404?code=200" do
    before { get "/404", params: { code: "200" } }

    it "ignores the query param and returns 404" do
      expect(response).to have_http_status(:not_found)
    end

    it "renders the 404 error page" do
      expect(response.body).to include("Страница не найдена")
    end
  end

  describe "GET /nonexistent-path" do
    before { get "/nonexistent-path" }

    it "returns 404 status" do
      expect(response).to have_http_status(:not_found)
    end

    it "renders the 404 error page" do
      expect(response.body).to include("Страница не найдена")
    end

    it "renders a link to the home page" do
      expect(response.body).to include("На главную")
    end
  end
end

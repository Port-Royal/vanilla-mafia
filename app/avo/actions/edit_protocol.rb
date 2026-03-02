class Avo::Actions::EditProtocol < Avo::BaseAction
  self.name = "Редактировать протокол"
  self.no_confirmation = true
  self.visible = -> { view.show? }

  def handle(records:, **_args)
    game = records.first
    redirect_to main_app.edit_judge_protocol_path(game), status: :see_other
  end
end

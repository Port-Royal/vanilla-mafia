class Avo::Actions::EditProtocol < Avo::BaseAction
  self.name = "Редактировать протокол"
  self.no_confirmation = true
  self.visible = -> { view.show? }

  def handle(records:, **_args)
    game = records.first
    redirect_to "/avo/game_protocols/#{game.id}/edit", status: :see_other
  end
end

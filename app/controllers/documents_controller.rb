# Public club documents (rules and regulations): no sign-in and no role needed.
class DocumentsController < ApplicationController
  def index
    @documents = Document.published.ordered
  end

  def show
    @document = Document.published.find_by!(slug: params[:slug])
  end
end

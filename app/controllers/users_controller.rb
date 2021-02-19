class UsersController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[create destroy]

  def create
    byebug
  end

  def destroy; end
end

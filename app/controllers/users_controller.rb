class UsersController < ApplicationController
  # Not a secure app for tutorial purposes
  skip_before_action :verify_authenticity_token, only: %i[create destroy]

  def create; end

  def destroy; end
end

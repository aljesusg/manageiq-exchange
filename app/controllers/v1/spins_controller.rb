module V1
  ###
  # Spins controller
  # Provides actions on the Spins
  #
  ##
  class SpinsController < ApplicationController
    before_action :authenticate_user!, only: [:refresh]
    ###
    # Index (search: string - optional )
    # Provides an index of all spins in the system
    # TODO If you provide a search team, it will return those spins mathing the search
    # TODO: Add paging
    def index
      @spins = Spin.all
      render json: { data: @spins }, status: :ok
    end

    ###
    # Show (id: identification of the spin)
    # Provides a view of the spin
    # TODO: When authenticated, provide extended info
    def show
      @spin = Spin.find_by(id: params[:id])
      render json: { data: @spin }, status: :ok
    end

    ###
    # Refresh
    # Authenticated only
    # Refresh the list of providers for the user.
    # Connects to github, gets all repos of the user, and search for spins
    #
    def refresh
      user = if current_user.admin?
               User.find(params[:user_id]) || current_user
             else
               current_user
             end
      if user.nil?
        render json: { error: 'No user found' }, status: :error
        return
      end

      job = RefreshSpinsJob.perform_later(user: user)
      render json: { data: job.job_id, metadata: { queue: job.queue_name, priority: job.priority } }, status: :ok
    end
  end
end
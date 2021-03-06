###
# __Background Job to refresh user spins__
# Will refresh all repos for a user and analyze them
# It will update them if found adfads
#
# @param  user: User
# @return boolean
#
class RefreshSpinsJob < ApplicationJob

  queue_as :default

  def perform(user:, token:)
    logger.info "Refresh Spins Job with user: #{user.id}"
    # Get the client using the application id (only public information)
    #
    client = Providers::BaseManager.new(user.authentication_tokens.first.provider).get_connector
    # Find the spins in the database, store them as an array
    user_spins = user.spins
    app_token = Tiddle::TokenIssuer.build.find_token(user, token)
    client.github_access.access_token = app_token.github_token
    user_spins_list = user_spins.map(&:id)
    # Get the list of repos in GitHub (they use the same id in github and local) for the user
    repos = client.repos(user: user, github_token: app_token.github_token)
    repos_list = repos.map(&:id)
    # List of deleted repos
    deleted_repos = user_spins_list - repos_list
    # Delete deleted repos
    Spin.where(id: deleted_repos).destroy_all
    # For each repo:
    # Verify that the repo has the proper structure
    # See if the repo is already in the database
    # If it is in the database, update it
    # If it is not in the database, add it to the database
    repos.each do |repo|
      spin = user_spins_list.include?(repo.id) ? Spin.find_by(id: repo.id) : Spin.new(id: repo.id, first_import: DateTime.current)
      if (spin.acceptable? user)
        releases = client.releases(repo.full_name) || []
        _metadata_raw, metadata_json = client.metadata(repo.full_name) || {}
        spin.update(name: repo.name,
                    full_name: repo.full_name,
                    description: repo.description,
                    clone_url: repo.clone_url,
                    html_url: repo.html_url,
                    issues_url: repo.rels[:issues].href,
                    forks_count: repo.forks_count,
                    stargazers_count: repo.stargazers_count,
                    watchers_count: repo.watchers,
                    open_issues_count: repo.open_issues_count,
                    size: repo.size,
                    gh_id: repo.id,
                    gh_created_at: repo.created_at,
                    gh_pushed_at: repo.pushed_at,
                    gh_updated_at: repo.updated_at,
                    gh_archived: repo.archived,
                    default_branch: repo.default_branch || 'master',
                    license_key: repo.license&.key,
                    license_name: repo.license&.name,
                    license_html_url: repo.license&.url,
                    version: metadata_json['spin_version'],
                    min_miq_version: metadata_json['min_miq_version'].downcase.bytes[0] - 'a'.bytes[0],
                    releases: releases,
                    user: user,
                    user_login: user.github_login)
      else
        spin.destroy unless spin.new_record?
      end
    end
  end
end

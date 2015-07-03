#!/usr/bin/env ruby

require 'csv'
require 'net/http'
require 'octokit'

class Repo
  extend Forwardable

  def initialize(repo_data)
    @repo_data = repo_data
  end

  def_delegators :@repo_data, :name, :full_name, :fork, :language

  def interesting?
    ! self.fork && language == "Ruby" && has_gemfile?
  end

  def ruby_version
    @_ruby_version ||= get_file_contents('.ruby-version').to_s.strip
  end

  def has_gemfile?
    ! gemfile.nil?
  end

  def gem?
    !! (gemfile =~ /^gemspec/)
  end

  def rails_version
    if gemfile =~ /gem\s+['"]rails['"], ['"](.*?)['"]/
      $1
    else
      "n/a"
    end
  end

  private

  def gemfile
    @_gemfile ||= get_file_contents('Gemfile')
  end

  def get_file_contents(filename)
    url = "https://raw.githubusercontent.com/#{full_name}/master/#{filename}"
    resp = Net::HTTP.get_response(URI.parse(url))
    if resp.is_a?(Net::HTTPSuccess)
      resp.body
    else
      nil
    end
  end
end

Octokit.auto_paginate = true

client = Octokit::Client.new(:access_token => ENV['access_token'])

csv = CSV.new(STDOUT)
csv << ['repo','ruby','gem','rails']
client.repos('alphagov', :sort => "full_name").each do |repo_data|
  repo = Repo.new(repo_data)
  next unless repo.interesting?
  csv << [repo.full_name, repo.ruby_version, repo.gem?, (repo.gem? ? '' : repo.rails_version)]
end

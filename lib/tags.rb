# frozen_string_literal: true

require 'config/log'
require 'config/d_registry'
require 'config/q_registry'
require 'kube_resource_fetcher'

class RepoTags
  def initialize(repo, commit)
    @repo = repo
    @commit = commit
  end

  def names
    @names ||= self.class.names images
  end

  def count
    names.count
  end

  def find
    @find_result ||= self.class.find images, commit
  end

  private

  attr_reader :repo, :commit

  def images
    @images ||= KubeResourceFetcher.new(repo, commit: commit).images.uniq
  rescue IOError => error
    if error.message.include? 'did not match any file(s) known to git'
      raise IOError, "cannot determine the tag for repo #{repo.name} "\
                     "and commit #{commit}"
    end
    raise error
  end

  class << self
    # NOTE: this is a class method for testing purposes
    def names(images)
      images.map do |image|
        ImageTags.new(image).names.map do |tag_name|
          tag_name
        end
      end.flatten.uniq
    end

    def find(images, commit)
      return nil if images.empty?
      images_without_tags = images.reject { |image| image.include? ':' }
      found_tags = images_without_tags.map do |image|
        find_single image, commit
      end.uniq
      found_tags.first if found_tags.size == 1
    end

    private

    # NOTE: The method .find_single queries the Docker Registry. There
    # is a exponential back off with maximum 55s of total waiting
    # implemented due to the slowly updated Registry.
    def find_single(image, commit, try: 1)
      tag_names = ImageTags.new(image).names
      found_tag = tag_names.find do |tag_name|
        tag_name.include? commit
      end
      if found_tag.nil? && try < 5
        sleep try**2
        find_single image, commit, try: try + 1
      else
        found_tag
      end
    end
  end
end

class ImageTags
  def initialize(full_image)
    @full_image = full_image # 'registry/org/name' or 'org/name'
  end

  def names
    Log.debug "get #{image_name} tags from registry #{registry}"
    @names ||= registry.tags(image_name)['tags']
  end

  def count
    names.count
  end

  private

  attr_reader :full_image

  def registry
    if full_image.start_with? 'quay.io'
      QRegistry
    else
      DRegistry
    end
  end

  def image_name
    full_image.sub('quay.io/', '')
  end
end

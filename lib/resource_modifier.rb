# frozen_string_literal: true

class ResourceModifier
  def initialize(resource, tag, canary)
    @original_resource = ResourceModifier.clone resource
    @tag = tag
    @canary = canary
  end

  # deployment resources get modified with the specific image of this commit
  def modified_resource
    @original_resource.
      tap(&modify_tag).
      tap(&modify_name).
      tap(&modify_labels).
      tap(&modify_replicas).
      tap(&modify_env)
  end

  private

  def modify_tag
    lambda do |resource|
      if modifiable? resource
        resource['spec']['template']['spec']['containers'].map do |container|
          image = container.fetch('image')
          container['image'] = image + ":#{@tag}" unless tag_specified?(image)
        end
      end
      resource
    end
  end

  def modify_name
    lambda do |resource|
      if @canary == true && modifiable?(resource)
        name = resource['metadata']['name']
        resource['metadata']['name'] = "#{name}-canary"
      end
      resource
    end
  end

  def modify_labels
    lambda do |resource|
      if @canary == true && modifiable?(resource)
        resource['spec']['template']['metadata']['labels']['track'] = 'canary'
      elsif @canary == false && modifiable?(resource)
        resource['spec']['template']['metadata']['labels']['track'] = 'stable'
      end
      resource
    end
  end

  def modify_replicas
    lambda do |resource|
      if @canary == true && modifiable?(resource)
        resource['spec']['replicas'] = 1
      end
      resource
    end
  end

  def modify_env
    lambda do |resource|
      if @canary == true && modifiable?(resource)
        resource['spec']['template']['spec']['containers'].map do |container|
          env = container['env']
          container['env'] =
            env.to_a + [{ 'name' => 'TRACK', 'value' => 'canary' }]
        end
      end
    end
  end

  def tag_specified?(image)
    !DockerImageParser.parse(image)[:tag].nil?
  end

  def modifiable?(resource)
    %w(Deployment StatefulSet).include? resource.fetch('kind')
  end

  class << self
    def clone(resource)
      Marshal.load(Marshal.dump(resource))
    end
  end
end

class DockerImageParser
  def self.parse(image)
    splitted = image.split(':')
    case splitted.count
    when 1 # image only
      { image: splitted[0] }
    when 2
      if splitted[1].include? '/' # registry with port, but no tag
        { image: splitted[0..1].join(':') }
      else
        { image: splitted[0], tag: splitted[1] }
      end
    when 3 # registry with port and tag
      { image: splitted[0..1].join(':'), tag: splitted[2] }
    else
      raise 'parse error...'
    end
  end
end

require "yaml"

module Dr
  class Config
    attr_reader :default_repo, :repositories

    def initialize(locations)
      @default_repo = nil
      @repositories = {}

      locations.each do |conf_file|
        conf_file = File.expand_path conf_file
        next unless File.exists? conf_file
        load conf_file
      end
    end

    private
    def load(path)
      conf_file = YAML::load_file path

      if conf_file.has_key? "repositories"
        if conf_file["repositories"].is_a? Array
          conf_file["repositories"].each do |repo|
            raise "Repo name missing in the config." unless repo.has_key? "name"
            raise "Repo location missing in the config" unless repo.has_key? "location"
            @repositories[repo["name"]] = {
              :location => repo["location"]
            }
          end
        else
          raise "The 'repositories' config option must be an array."
        end
      end

      if conf_file.has_key? "default_repo"
        @default_repo = conf_file["default_repo"]
        unless @repositories.has_key? @default_repo
          raise "Default repo #{@default_repo} doesn't exist"
        end
      end
    end
  end
end

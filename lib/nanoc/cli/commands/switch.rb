module Nanoc::CLI

  class SwitchCommand < Command # :nodoc:

    def name
      'switch'
    end

    def aliases
      []
    end

    def short_desc
      'switch the site to a new data source'
    end

    def long_desc
      'Move the data stored in the site to a new, given data source.' +
      "\n" +
      'The given new data source may need additional configuration ' +
      'parameters that cannot be specified on the commandline. These ' +
      'should be stored in the configuration file (config.yaml) BEFORE ' +
      'executing the switch command.' +
      "\n" +
      'This command first loads all existing data into memory, destroys ' +
      'the on-disk data, changes the site\'s data source, and finally ' +
      'writes the data back to the disk using the new data source. Because ' +
      'of this action\'s destructive nature, THIS OPERATION SHOULD NOT BE ' +
      'INTERRUPTED as interruption could result in data loss.' +
      "\n" +
      'This command will change data, and it is therefore recommended to ' +
      'make a backup in case something goes wrong.'
    end

    def usage
      "nanoc switch [options]"
    end

    def option_definitions
      [
        # --yes
        {
          :long => 'yes', :short => 'y', :argument => :forbidden,
          :desc => 'switches the data source without warning'
        },
        # --datasource
        {
          :long => 'datasource', :short => 'd', :argument => :required,
          :desc => 'specify the new data source for the site'
        }
      ]
    end

    def run(options, arguments)
      # Check arguments
      if arguments.size != 0
        puts "usage: #{usage}"
        exit 1
      end

      # Check options
      unless options.has_key?(:datasource)
        puts 'A new data source should be specified using the ' +
             '-d/--datasource option.'
        exit 1
      end

      # Find data source
      data_source = Nanoc::PluginManager.instance.data_source(options[:datasource].to_sym)
      if data_source.nil?
        puts "Unrecognised data source: #{options[:datasource]}"
        exit 1
      end

      # Make sure we are in a nanoc site directory
      @base.require_site

      # Check for -y switch
      unless options.has_key?(:yes)
        puts 'Are you absolutely sure you want to set up the data source ' +
             'for this site? Setting up the data source will remove ' +
             'existing data. To continue, use the -y/--yes option, like ' +
             '"nanoc setup -y".'
        exit 1
      end

      # Load data
      @base.site.load_data

      # Destroy existing data
      @base.site.data_source.destroy

      # Update configuration
      @base.site.config[:data_source] = options[:datasource]
      @base.site.instance_eval { @data_source = data_source.new(self) }
      File.open('config.yaml', 'w') { |io| io.write(YAML.dump(@base.site.config.stringify_keys)) }

      @base.site.data_source.loading do
        # Create initial data source
        @base.site.data_source.setup

        # Store all data
        @base.site.pages.each { |p| @base.site.data_source.save_page(p) }
        @base.site.data_source.save_page_defaults(@base.site.page_defaults)
        @base.site.layouts.each { |l| @base.site.data_source.save_layout(l) }
        @base.site.templates.each { |t| @base.site.data_source.save_template(t) }
        @base.site.data_source.save_code(@base.site.code)
      end
    end

  end

end
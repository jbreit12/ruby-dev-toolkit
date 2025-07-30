# lib/rdt/project_initializer.rb

module RDT
  # This class is responsible for setting up the project scaffolding
  class ProjectInitializer
    DEFAULT_FOLDERS = ["src", "tests", "docs"].freeze # default subfolders to use if none specified

    # Method for running the tool from the CLI
    def self.run(args = [])

      project_name = args[0] # Takes the first CLI argument as the name of the new project folder.

      # Validate input
      if project_name.nil? || project_name.strip.empty?
        puts "Error: You must provide a project name."
        puts "Usage: rdt init_project MyProject [--no-license] [--folders=src,assets]"
        return
      end

      options = parse_options(args[1..])  # Options after the project name e.g. --no-licence or --folders
      create_project_structure(project_name, options) # Call method which builds the project
    end

    def self.parse_options(args)
      # Default options
      options = {
        license: true,
        folders: DEFAULT_FOLDERS
      }

      # Loop through each argument to override defaults
      args.each do |arg|
        if arg == '--no-license'
          options[:license] = false
        elsif arg.start_with?('--folders=')
          folder_list = arg.split('=', 2)[1] # Split string into 2 parts at the '=' and access second part
          options[:folders] = folder_list.split(',').map(&:strip) # Splits string at commas into an array and trims whitespace
        end
      end

      return options
    end

    # This method creates the folder structure and files
    def self.create_project_structure(name, options)
      # Make sure directory does not already exist
      if Dir.exist?(name)
        puts "Error: Directory '#{name}' already exists."
        return
      end

      puts "Creating project: #{name}"
      Dir.mkdir(name) # Create main project folder

      # Change into the project folder
      Dir.chdir(name) do
        File.write("README.md", "# #{name}\n\nProject initialized by RDT.") # Create basic README
        File.write(".gitignore", "# Ignore Ruby temp files\n*.gem\n*.rbc\n") # Create default .gitignore file
        File.write("LICENSE", "MIT License Placeholder") if options[:license] # Create license file if option enabled

        # Create folder(s) specified in option
        options[:folders].each do |folder|
          Dir.mkdir(folder)
        end
      end

      puts "Project '#{name}' created successfully."
    end
  end
end

# lib/rdt/readme_generator.rb
require "fileutils"
require "etc"

module RDT
  class ReadmeGenerator
    DEFAULT_OUT     = "README.md".freeze
    DEFAULT_LICENSE = "MIT".freeze

    # Entry point; accepts the remaining ARGV array
    def self.run(args = [])
      opts = parse_options(args)
      opts[:out] ||= DEFAULT_OUT

      # Interactive mode if name/desc are missing
      unless opts[:name] && opts[:desc]
        puts "Entering interactive mode (press Enter to accept defaults)."
        opts[:name]    ||= prompt("Project name", default: infer_project_name)
        opts[:desc]    ||= prompt("Short description", default: "A simple project initialized with RDT.")
        opts[:author]  ||= prompt("Author", default: default_author)
        opts[:license] ||= prompt("License (MIT/Apache-2.0/Unlicense/None)", default: DEFAULT_LICENSE)
        opts[:out]     ||= prompt("Output file", default: DEFAULT_OUT)
      end

      # Overwrite guard unless forced
      if File.exist?(opts[:out]) && !opts[:force]
        print "#{opts[:out]} exists. Overwrite? (y/N): "
        ans = STDIN.gets&.chomp&.downcase
        return puts "Cancelled." unless ans == "y"
      end

      content = build_readme(opts)
      write_file(opts[:out], content)
      puts "README generated at #{opts[:out]}"
    end

    # -------- Helpers --------

    def self.parse_options(args)
      # Manual flag parsing: --name=, --desc=, --author=, --license=, --out=, --force
      # Tip: quote values with spaces: --desc="My cool app"
      opts = {}
      args.each do |arg|
        if arg.start_with?("--name=")
          opts[:name] = take_value(arg)
        elsif arg.start_with?("--desc=")
          opts[:desc] = take_value(arg)
        elsif arg.start_with?("--author=")
          opts[:author] = take_value(arg)
        elsif arg.start_with?("--license=")
          opts[:license] = take_value(arg)
        elsif arg.start_with?("--out=")
          opts[:out] = take_value(arg)
        elsif arg == "--force"
          opts[:force] = true
        elsif ["-h", "--help"].include?(arg)
          print_help
          exit 0
        end
      end
      opts
    end

    def self.take_value(arg)
      arg.split("=", 2)[1].to_s.strip
    end

    def self.print_help
      puts <<~HELP
        Usage:
          rdt readme_gen [--name=MyApp] [--desc="Short description"] [--author="You"]
                         [--license=MIT|Apache-2.0|Unlicense/None] [--out=README.md] [--force]

        Examples:
          rdt readme_gen --name=InventoryTracker --desc="Track parts in a garage" --author="John B."
          rdt readme_gen --name=MyApp --license=Apache-2.0 --out=docs/README.md
          rdt readme_gen --force --out=README.md

        Notes:
          - If required fields are missing, you'll be prompted interactively.
          - Quote values that contain spaces: --desc="My great project"
          - Use --force to overwrite an existing file without prompting.
      HELP
    end

    def self.prompt(label, default: nil)
      print "#{label}#{default ? " [#{default}]" : ""}: "
      input = STDIN.gets&.chomp
      input.nil? || input.strip.empty? ? default : input.strip
    end

    def self.infer_project_name
      # Use current directory name as a decent default
      File.basename(Dir.pwd)
    end

    def self.default_author
      # Try git config, then ENV/Etc
      git_name = `git config user.name`.to_s.strip
      return git_name unless git_name.empty?
      ENV["USER"] || Etc.getlogin || "Anonymous"
    rescue
      ENV["USER"] || "Anonymous"
    end

    def self.build_readme(opts)
      name    = (opts[:name]    || infer_project_name).strip
      desc    = (opts[:desc]    || "A simple project initialized with RDT.").strip
      author  = (opts[:author]  || default_author).strip
      license = (opts[:license] || DEFAULT_LICENSE).strip

      license_badge = badge_for_license(license)

      sections = [
        "# #{name}",
        (license_badge unless license_badge.empty?),
        "",
        "## Description",
        desc,
        "",
        "## Getting Started",
        "```bash",
        "# install deps if you have a Gemfile",
        "bundle install",
        "",
        "# run your app or CLI here",
        "```",
        "",
        "## Usage",
        "- Explain how to run or use this project.",
        "",
        "## Author",
        author,
      ]

      unless license.casecmp("None").zero?
        sections += [
          "",
          "## License",
          license_text(license)
        ]
      end

      sections.compact.join("\n")
    end

    def self.badge_for_license(license)
      case license
      when /MIT/i
        "![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)"
      when /Apache-?2\.0/i
        "![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)"
      when /Unlicense/i
        "![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)"
      when /None/i
        ""
      else
        ""
      end
    end

    def self.license_text(license)
      case license
      when /MIT/i
        "This project is licensed under the MIT License."
      when /Apache-?2\.0/i
        "This project is licensed under the Apache 2.0 License."
      when /Unlicense/i
        "This project is released into the public domain under The Unlicense."
      else
        "License: #{license}"
      end
    end

    def self.write_file(path, content)
      path ||= DEFAULT_OUT
      dir = File.dirname(path)
      FileUtils.mkdir_p(dir) unless dir == "."
      File.write(path, content)
    end
  end
end

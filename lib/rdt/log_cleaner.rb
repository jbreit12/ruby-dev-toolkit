#lib/rdt/log_cleaner.rb

require 'fileutils'

module RDT
  # This class is responsible for cleaning log and temporary files
  class LogCleaner
    DEFAULT_PATTERNS = ["*.log", "*.tmp", "*.bak", "tmp/**/*", "log/**/*"].freeze

    # Entry point for running from CLI
    def self.run(args = [])
    # Split into base_dir (first non-flag) and flags (all starting with --)
      base_dir = nil
      flags = []
      args.each do |a|
        if a.start_with?('--')
          flags << a
        else
          base_dir ||= a
        end
      end

      base_dir ||= Dir.pwd
      patterns  = parse_patterns(flags)             # pass only flags here
      confirm   = flags.include?('--confirm')

      clean_files(base_dir, patterns, confirm)
    end

    def self.parse_patterns(args)
      args = Array(args)                            # ensure it's an array, not nil
      custom = args.find { |arg| arg.start_with?('--patterns=') }
      if custom
        custom.split('=', 2)[1].split(',').map(&:strip)
      else
        DEFAULT_PATTERNS
      end
    end


    # Scan for matching files and clean them (with optional confirmation)
    def self.clean_files(base_dir, patterns, auto_confirm)
      unless Dir.exist?(base_dir)
        puts "Error: Directory '#{base_dir}' does not exist."
        return
      end

      puts "Scanning '#{base_dir}' for log/temp files..."
      files_to_delete = []

      patterns.each do |pattern|
        Dir.glob(File.join(base_dir, pattern)) do |file|
          files_to_delete << file if File.file?(file)
        end
      end

      if files_to_delete.empty?
        puts "No log or temp files found."
        return
      end

      puts "Found #{files_to_delete.size} file(s) to delete:"
      files_to_delete.each { |f| puts "  - #{f}" }

      unless auto_confirm
        print "Do you want to delete these files? (y/N): "
        answer = STDIN.gets.chomp.downcase
        return puts "Cancelled." unless answer == 'y'
      end

      files_to_delete.each { |file| FileUtils.rm_f(file) }
      puts "Deleted #{files_to_delete.size} file(s)."
    end
  end
end

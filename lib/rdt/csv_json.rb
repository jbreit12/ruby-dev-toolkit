# lib/rdt/csv_json_converter.rb
require "csv"
require "json"
require "fileutils"

module RDT
  # CSV ↔ JSON converter with guardrails and small options
  #
  # Usage:
  #   rdt csv_json convert input.csv output.json [--delimiter=";"] [--force]
  #   rdt csv_json reverse input.json output.csv [--delimiter=";"] [--force]
  #   rdt csv_json help
  #
  class CsvJsonConverter
    def self.run(args = [])
      return print_help if args.empty? || %w[-h --help help].include?(args[0])

      mode, input_path, output_path, *rest = args

      if mode.nil? || input_path.nil? || output_path.nil?
        puts "Error: Missing arguments.\n\n"
        return print_help
      end

      opts = parse_opts(rest)

      unless File.exist?(input_path)
        puts "Error: Input file '#{input_path}' does not exist."
        return
      end

      if File.exist?(output_path) && !opts[:force]
        print "#{output_path} exists. Overwrite? (y/N): "
        ans = STDIN.gets&.chomp&.downcase
        return puts "Cancelled." unless ans == "y"
      end

      ensure_parent_dir(output_path)

      case mode
      when "convert" # CSV -> JSON
        convert_csv_to_json(input_path, output_path, opts)
      when "reverse" # JSON -> CSV
        convert_json_to_csv(input_path, output_path, opts)
      else
        puts "Error: Invalid mode '#{mode}'. Use 'convert' or 'reverse'.\n\n"
        print_help
      end
    end

    # ---------------- helpers ----------------

    def self.print_help
      puts <<~H
        Usage:
          rdt csv_json convert <input.csv> <output.json> [--delimiter=";"] [--force]
          rdt csv_json reverse <input.json> <output.csv> [--delimiter=";"] [--force]

        Notes:
          - CSV → JSON expects a header row by default.
          - Use --delimiter to read/write non-comma CSV (e.g., --delimiter=";").
          - --force skips overwrite confirmation.
      H
      nil
    end

    def self.parse_opts(rest)
      opts = { force: false, delimiter: "," }
      rest.each do |arg|
        if arg == "--force"
          opts[:force] = true
        elsif arg.start_with?("--delimiter=")
          val = arg.split("=", 2)[1]
          opts[:delimiter] = val.to_s.empty? ? "," : val
        end
      end
      opts
    end

    def self.ensure_parent_dir(path)
      dir = File.dirname(path)
      FileUtils.mkdir_p(dir) unless dir == "."
    end

    # ---------------- conversions ----------------

    def self.convert_csv_to_json(input_path, output_path, opts)
      # Read CSV with headers; handle different delimiters
      csv_data = CSV.read(
        input_path,
        headers: true,
        col_sep: opts[:delimiter]
      )

      # Convert rows to array of hashes (string keys)
      json_array = csv_data.map(&:to_h)

      File.write(output_path, JSON.pretty_generate(json_array))
      puts "CSV converted to JSON: #{output_path}"
    rescue CSV::MalformedCSVError => e
      puts "Error: Malformed CSV (#{e.message}). Try adjusting --delimiter."
    end

    def self.convert_json_to_csv(input_path, output_path, opts)
      raw = File.read(input_path)
      json_data = JSON.parse(raw)

      unless json_data.is_a?(Array)
        puts "Error: JSON root must be an array (e.g., [{...}, {...}])."
        return
      end

      # Normalize: allow arrays of scalars by wrapping them under 'value'
      if !json_data.empty? && !json_data.first.is_a?(Hash)
        json_data = json_data.map { |v| { "value" => v } }
      end

      # Build header set from union of keys across all rows
      headers = json_data.flat_map(&:keys).uniq

      CSV.open(output_path, "w", col_sep: opts[:delimiter]) do |csv|
        csv << headers
        json_data.each do |row|
          csv << headers.map { |h| row[h] }
        end
      end

      puts "JSON converted to CSV: #{output_path}"
    rescue JSON::ParserError => e
      puts "Error: Invalid JSON (#{e.message})."
    end
  end
end

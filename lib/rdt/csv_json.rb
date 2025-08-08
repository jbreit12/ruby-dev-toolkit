require 'csv'
require 'json'

module RDT
  # This class converts CSV files to JSON format and vice versa
  class CsvJsonConverter
    # Entry point for CLI
    def self.run(args = [])
      if args.size < 2
        puts "Error: Missing arguments."
        puts "Usage: rdt csv_json convert input.csv output.json"
        puts "       rdt csv_json reverse input.json output.csv"
        return
      end

      mode = args[0]
      input_path = args[1]
      output_path = args[2]

      unless File.exist?(input_path)
        puts "Error: Input file '#{input_path}' does not exist."
        return
      end

      case mode
      when "convert"
        convert_csv_to_json(input_path, output_path)
      when "reverse"
        convert_json_to_csv(input_path, output_path)
      else
        puts "Error: Invalid mode '#{mode}'. Use 'convert' or 'reverse'."
      end
    end

    def self.convert_csv_to_json(input_path, output_path)
      csv_data = CSV.read(input_path, headers: true)
      json_array = csv_data.map(&:to_h)

      File.write(output_path, JSON.pretty_generate(json_array))
      puts "CSV converted to JSON: #{output_path}"
    end

    def self.convert_json_to_csv(input_path, output_path)
      json_data = JSON.parse(File.read(input_path))
      unless json_data.is_a?(Array) && json_data.first.is_a?(Hash)
        puts "Error: JSON must be an array of objects to convert to CSV."
        return
      end

      headers = json_data.first.keys
      CSV.open(output_path, "w") do |csv|
        csv << headers
        json_data.each { |row| csv << headers.map { |h| row[h] } }
      end

      puts "JSON converted to CSV: #{output_path}"
    end
  end
end

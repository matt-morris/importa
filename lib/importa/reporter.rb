# frozen_string_literal: true

module Importa
  class Reporter
    attr_reader :transformed_records, :invalid_records

    def initialize
      @start_time = Time.now
      @transformed_records = 0
      @invalid_records = []
    end

    def record_transformed
      @transformed_records += 1
    end

    def record_invalid(row_number, errors)
      @invalid_records << {row: row_number, errors: errors}
    end

    def report
      total_records = @transformed_records + @invalid_records.count

      File.write("report.txt", [
        "Importa report:",
        "---------------",
        "Started at: #{@start_time}",
        "Finished at: #{Time.now}",
        "Duration: #{Time.now - @start_time} seconds",
        "Total records: #{total_records}",
        "Transformed records: #{@transformed_records}",
        "Invalid records: #{@invalid_records.count}",
        "Errors:",
        @invalid_records.map do |record|
          ["Row #{record[:row]}, Errors: #{record[:errors].count}",
            record[:errors].map do |error|
              "- #{error[0]} #{error[1]}"
            end]
        end
      ].flatten.join("\n"))
    end
  end
end

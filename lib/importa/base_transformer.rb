# frozen_string_literal: true

module Importa
  class BaseTransformer
    attr_reader :input, :output, :errors
    attr_accessor :reporter
    @field_names = []
    @formatters = {}

    FORMATTERS = {
      raw: ->(value) { value },
      string: ->(value) { value.to_s.strip },
      date: ->(value) {
        [
          ["%m-%d-%y", /^\d{1,2}-\d{1,2}-\d{2}$/], # 1-11-88
          ["%m/%d/%y", /^\d{1,2}\/\d{1,2}\/\d{2}$/], # 01/11/88
          ["%m-%d-%Y", /^\d{1,2}-\d{1,2}-\d{4}$/], # 01-11-1988
          ["%m/%d/%Y", /^\d{1,2}\/\d{1,2}\/\d{4}$/], # 01/11/1988
          ["%m-%d-%y", /^\d{1,2}-\d{1,2}-\d{4}$/], # 01-11-1988
          ["%m/%d/%y", /^\d{1,2}\/\d{1,2}\/\d{2}$/], # 01/11/88
          ["%d-%m-%y", /^\d{1,2}-\d{1,2}-\d{2}$/], # 11-01-88
          ["%d/%m/%y", /^\d{1,2}\/\d{1,2}\/\d{2}$/], # 11/01/88
          ["%d-%m-%Y", /^\d{1,2}-\d{1,2}-\d{4}$/], # 11-01-1988
          ["%d/%m/%Y", /^\d{1,2}\/\d{1,2}\/\d{4}$/], # 11/01/1988
          ["%Y-%m-%d", /^\d{4}-\d{2}-\d{2}$/], # 1988-01-11
          ["%d-%m-%Y", /^\d{1,2}-\d{1,2}-\d{4}$/], # 11-01-1988
          ["%Y/%m/%d", /^\d{4}\/\d{2}\/\d{2}$/], # 1988/01/11
          ["%d/%m/%Y", /^\d{1,2}\/\d{1,2}\/\d{4}$/], # 11/01/1988
          ["%B %d, %Y", /^[A-Za-z]+ \d{1,2}, \d{4}$/], # January 11, 1988
          ["%b %d, %Y", /^[A-Za-z]{3} \d{1,2}, \d{4}$/], # Jan 11, 1988
          ["%d %B, %Y", /^\d{1,2} [A-Za-z]+, \d{4}$/], # 11 January, 1988
          ["%d %b, %Y", /^\d{1,2} [A-Za-z]{3}, \d{4}$/] # 11 Jan, 1988
        ].each do |format, regex|
          next unless value.to_s.match?(regex)
          return Date.strptime(value.to_s, format).iso8601
        rescue ArgumentError
          next
        rescue
          nil
        end
        nil
      },
      phone: ->(value) {
        cleaned_value = value.to_s.gsub(/\D/, "").sub(/^1/, "")
        (cleaned_value.length == 10) ? "+1#{cleaned_value}" : nil
      },

      # other types aren't necessary for the exercise, but easy and useful
      integer: ->(value) { value.to_i },
      float: ->(value) { value.to_f },
      boolean: ->(value) { value == "true" }
    }

    # we want to make sure that subclasses have their own copies of these
    def self.inherited(subclass)
      subclass.instance_variable_set(:@field_names, [])
      subclass.instance_variable_set(:@formatters, FORMATTERS.dup)
    end

    class << self
      attr_reader :field_names, :formatters

      # this is where the magic happens:
      # importers define a mapping using the `field` DSL
      # - optionally provide a formatter type (defaults to :string, as that's the most common)
      # - providing a block will allow you to do custom formatting or quick one-offs
      # - optional: true will allow the field to be nil or empty
      def field(name, type = :string, optional: false, &block)
        @field_names.push(name)
        formatter = @formatters[type]
        define_method("field_#{name}") do
          value = input[name.to_s]
          value = formatter.call(value)
          value = instance_exec(value, &block) if block
          @errors.push([name, "is required"]) if !optional && (value.nil? || value.empty?)
          value
        end
      end

      def formatter(name, formatter_lambda = nil, &block)
        @formatters[name] = formatter_lambda || block
      end
    end

    def initialize(input, row_number = nil)
      @input = input
      @row_number = row_number
      @errors = []
      @run_at = nil
    end

    def [](name)
      send("field_#{name}")
    end

    def valid?
      transform unless @run_at
      @errors.empty?
    end

    def transform
      @errors = []
      @run_at = Time.now
      results = self.class.field_names.map do |name|
        send("field_#{name}")
      end
      valid? ? reporter&.record_transformed : reporter&.record_invalid(@row_number, @errors)

      results
    end

    def self.transform_batch(input, reporter = nil)
      reporter ||= Reporter.new
      results = []
      input.each.with_index do |row, index|
        t = new(row, index)
        t.reporter = reporter
        row = t.transform
        results.push(row) if t.valid?
      end
      reporter.report
      results
    end
  end
end

# frozen_string_literal: true

require 'rubulator/version'

class Rubulator
  class CalculationError < StandardError; end

  # Store and retrieve the value of a variable.
  class Variable
    def initialize(name, value = nil)
      @name = name
      @value = value
    end

    def store(value)
      @value = value.to_f
    end

    def to_f
      raise CalculationError, "Variable '#{@name}' not set" unless @value

      @value.to_f
    end
  end

  attr_accessor :variables

  def initialize
    @variables = {}

    result.store(0.0)
  end

  def self.calculate(expression)
    Rubulator.new.calculate(expression)
  end

  def result
    @variables[RESULT_VARIABLE] ||= Variable.new(RESULT_VARIABLE)
  end

  def calculate(expression)
    return unless expression && expression != ''

    operands = expression.sub(/^\s+/, '').sub(/\s+$/, '').split(/\s+/)
    result.store(consume(nil, 'initial', operands).to_f)

    unless operands.empty?
      raise CalculationError, "Operands #{operands.inspect} left over in expression '#{expression}'"
    end

    result.to_f
  end

  def operators
    ['='] + OPERATORS
  end

  def functions
    MATH_FUNCTIONS
  end

  def constants
    MATH_CONSTANTS.keys.map(&:to_s)
  end

  def variable_names
    variables.keys.map { |v| VARIABLE_PREFIX + v }
  end

  private

  VARIABLE_PREFIX = '$'
  VARIABLE_PREFIX_MATCH_RE = Regexp.new("^#{Regexp.escape(VARIABLE_PREFIX)}")

  RESULT_VARIABLE = '$'

  OPERATORS = %w[+ - * / % **].freeze

  MATH_CONSTANTS = {
    pi: Math::PI,
    e: Math::E
  }.freeze

  MATH_FUNCTIONS = %w[sqrt cbrt sin sinh cos cosh tan tanh atan atanh log log2 log10].freeze

  def consume(operator, name, operands)
    raise CalculationError, "Missing #{name} operand for '#{operator || 'main expression'}'" if operands.empty?

    operand = operands.shift

    case # rubocop:disable Style/EmptyCaseCondition
    when operand == '='
      variable = consume('=', 'assignment variable', operands)
      unless variable.is_a?(Variable)
        raise CalculationError, "Variable expected for 1st operand, found '#{variable}' instead"
      end

      value = consume('=', 'value', operands).to_f

      variable.store(value)
    when operand.start_with?(VARIABLE_PREFIX)
      name = operand.sub(VARIABLE_PREFIX_MATCH_RE, '')
      raise CalculationError, "No variable name provided for '$'" if name == ''

      @variables[name] ||= Variable.new(name)
    when operand == ','
      consume(',', '1st', operands)
      consume(',', '2nd', operands)
    when OPERATORS.include?(operand)
      op1 = consume(operand, '1st', operands).to_f
      op2 = consume(operand, '2nd', operands).to_f
      op1.send(operand.to_sym, op2)
    when MATH_FUNCTIONS.include?(operand)
      op1 = consume(operand, 'input', operands).to_f
      Math.send(operand.to_sym, op1)
    when MATH_CONSTANTS.include?(operand.downcase.to_sym)
      MATH_CONSTANTS.fetch(operand.downcase.to_sym)
    when /[+-]?[0-9][0-9.]*/.match(operand)
      operand
    else
      raise CalculationError, "Unknown argument '#{operand}'"
    end
  end
end

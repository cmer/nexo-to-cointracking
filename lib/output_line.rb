class OutputLine
  # Represents a line in the Cointracking output CSV
  attr_reader :input_line
  attr_writer :type, :buy_currency, :sell_currency, :buy_amount, :sell_amount

  TYPES_CONVERSION = {
    "Deposit" => ["Deposit", nil],
    "Interest" => ["Interest Income", "Borrowing Fee"],
    "Withdrawal" => [nil, "Withdrawal"],
    "Liquidation" => :skip,
    "Repayment" => :skip,
    "WithdrawalCredit" => [nil, "Withdrawal"],
    "Exchange" => :skip,
    "TransferIn" => :skip,
    "TransferOut" => :skip
  }

  def initialize(input_line)
    @input_line = input_line
  end

  def to_a
    out = []
    out << type
    out << buy_amount
    out << buy_currency.to_s.upcase
    out << sell_amount
    out << sell_currency.to_s.upcase
    out << nil # fee amount
    out << nil # fee currency
    out << "Nexo"
    out << nil  # trade group
    out << input_line.original_type + ": " + input_line.details
    out << input_line.date
    out
  end

  def to_s
    to_a.join(",")
  end

  def add_to_output?
    type != nil
  end

  private

  def buy?
    input_line.amount_is_positive? || input_line.liquidation?
  end

  def sell?
    !input_line.amount_is_positive? || input_line.liquidation?
  end

  def buy_amount
    return @buy_amount if @buy_amount
    buy? ? input_line.amount.strip : nil
  end

  def sell_amount
    return @sell_amount if @sell_amount
    sell? ? input_line.amount.strip.sub(/^\-/, '') : nil
  end

  def buy_currency
    return @buy_currency if @buy_currency
    buy? ? input_line.currency : nil
  end

  def sell_currency
    return @sell_currency if @sell_currency
    sell? ? input_line.currency : nil
  end

  def comment
    input_line.type
  end

  def type
    return @type if @type
    val = value_for(TYPES_CONVERSION, input_line.original_type)
    return nil if val == :skip

    if (!TYPES_CONVERSION.keys.include?(input_line.original_type) || val.nil?)
      raise ArgumentError.new("Could not translate transaction type for #{input_line.original_type} in the amount of #{input_line.amount} #{input_line.currency}")
    end

    val
  end

  def value_for(collection, key)
    return collection[key] if collection[key] == :skip
    if amount_is_positive?
      collection[key].first
    else
      collection[key].last
    end
  rescue; binding.pry
  end

  def amount_is_positive?
    !(input_line.amount =~ /^\-/)
  end

end

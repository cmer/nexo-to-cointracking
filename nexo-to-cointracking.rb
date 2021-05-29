#!/usr/bin/env ruby

require 'csv'

class InputLine
  attr_reader :ary

  # HEADER
  # "Transaction", "Type", "Currency", "Amount", "USD Equivalent", "Details", "Outstanding Loan", "Date / Time"

  TYPES = {
    "Deposit" => ["Deposit", nil],
    "Interest" => ["Interest Income", "Borrowing Fee"],
    "Withdrawal" => [nil, "Withdrawal"],
    "Liquidation" => [nil, "Trade"],
    "Repayment" => ["Deposit", nil],
    "WithdrawalCredit" => [nil, "Withdrawal"],
    "TransferIn" => ["Deposit", nil],
    "TransferOut" => [nil, "Withdrawal"]
  }

  def initialize(ary)
    @ary = if ary.is_a?(String)
      ary.split(',')
    else
      ary
    end
  end

  def type
    val = value_for(TYPES, original_type)
    raise ArgumentError.new("Could not translate transaction type for #{original_type} in the amount of #{amount} #{currency}") unless val
    val
  # rescue
  #   require 'pry'
  #   binding.pry
  end

  def original_type
    ary[1].strip
  end

  def amount
    ary[3].strip
  end

  def usd_equivalent
    ary[4].strip
  end

  def currency(col = 2)
    case ary[col]
    when "USDTERC"
      "USDT"
    when "NEXONEXO"
      "NEXO"
    else
      ary[col]
    end
  end

  def amount_is_positive?
    !(amount =~ /^\-/)
  end

  def date
    ary[7]
  end

  def details
    ary[5]
  end

  private

  def value_for(collection, key)
    if amount_is_positive?
      collection[key].first
    else
      collection[key].last
    end
  end
end

class OutputLine
  attr_reader :input_line

  def initialize(input_line)
    @input_line = input_line
  end

  def to_a
    out = []
    out << input_line.type
    out << buy_amount
    out << buy_currency
    out << sell_amount
    out << sell_currency
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

  private

  def buy?
    input_line.amount_is_positive? || liquidation?
  end

  def sell?
    !input_line.amount_is_positive? || liquidation?
  end

  def liquidation?
    input_line.original_type == "Liquidation"
  end

  def buy_amount
    buy? ? input_line.amount.strip : nil
  end

  def sell_amount
    if liquidation?
      input_line.usd_equivalent
    elsif sell?
      input_line.amount.strip.sub(/^\-/, '')
    end
  end

  def buy_currency
    buy? ? input_line.currency : nil
  end

  def sell_currency
    if liquidation?
      "USDT"
    elsif sell?
      input_line.currency
    end
  end

  def comment
    input_line.type
  end
end

class NexoToCointrackingCSV
  attr_reader :input_path, :output_path, :rows

  def initialize(input_path, output_path)
    @input_path, @output_path = File.expand_path(input_path), File.expand_path(output_path)
  end

  def save!
    generate_rows
    save_to_file
  end

  private

  def generate_rows
    @rows = []
    i = 0

    CSV.foreach(input_path) do |input_row|
      if i > 0
        input_csv_line = InputLine.new(input_row)
        @rows << OutputLine.new(input_csv_line).to_a
      end
      i += 1
    end

    @rows
  end

  def save_to_file
    CSV.open(output_path, "wb") do |csv|
      csv << header
      rows.each do |row|
        csv << row
      end
    end
  end

  def header
    ["Type", "Buy", "Cur.", "Sell", "Cur.", "Fee", "Cur.", "Exchange", "Group", "Comment", "Date"]
  end
end

NexoToCointrackingCSV.new("~/Downloads/nexo_transactions.csv", "~/Downloads/nexo_ct.csv").save!
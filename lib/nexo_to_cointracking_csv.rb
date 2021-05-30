class NexoToCointrackingCSV
  attr_reader :input_path, :rows, :nexo_transactions

  def initialize(input_path, output_path = nil)
    @input_path = File.expand_path(input_path)
  end

  def print
    run
    print_to_screen
  end

  def save_to(output_path)
    run
    save_to_file(output_path)
  end

  def run
    load_nexo_transactions
    generate_rows
  end

  private

  def generate_rows
    @rows = []
    liquidation_row = nil

    nexo_transactions.each do |input_line|
      if input_line.liquidation?
        liquidation_row = input_line
        next
      elsif input_line.repayment?
        raise "Liquidation Row not found for repayment #{input_line.txn_id}" unless liquidation_row
        output_line = OutputLine.new(input_line)
        output_line.buy_currency = 'USDT'
        output_line.buy_amount = liquidation_proceeds(liquidation_row, input_line)
        output_line.sell_currency = liquidation_row.currency
        output_line.sell_amount = liquidation_row.amount.strip.sub(/^\-/,'')
        output_line.type = 'Trade'
        liquidation_row = nil
      elsif input_line.exchange?
        output_line = OutputLine.new(input_line)
        sell_amount, buy_amount = input_line.amount
        sell_currency, buy_currency = input_line.currency
        output_line.buy_currency = buy_currency
        output_line.buy_amount = buy_amount
        output_line.sell_currency = sell_currency
        output_line.sell_amount = sell_amount
        output_line.type = 'Trade'
      else
        output_line = OutputLine.new(input_line)
      end

      @rows << output_line.to_a if output_line.add_to_output?
    end

    @rows
  end

  def save_to_file(output_path)
    output_path = File.expand_path(output_path)
    CSV.open(output_path, "wb") do |csv|
      csv << output_header
      rows.each do |row|
        csv << row
      end
    end
  end

  def print_to_screen
    puts output_header.join(",")
    rows.each do |row|
      puts row.join(",")
    end
  end

  def liquidation_proceeds(liquidation_row, repayment_row)
    # Liquidation and repayments are represented as 2 lines on the Nexo side.
    # Cointracking expects a single line.
    #
    # Because of fees and the way repayments are recalculated, the only way to
    # determine how much is being actually repaid on the loan is to calculate
    # the difference between the outstanding loan before and after repayment.
    raise ArgumentError.new("Expected 'Liquidation', got '#{liquidation_row.original_type}'") unless liquidation_row.liquidation?
    raise ArgumentError.new("Expected 'Repayment', got '#{repayment_row.original_type}'") unless repayment_row.repayment?
    raise ArgumentError.new("Expected Outstanding Loan Balance to be higher before repayment. Before: $#{liquidation_row.outstanding_loan}, After: $#{repayment_row.outstanding_loan}.") unless liquidation_row.outstanding_loan.to_f > repayment_row.outstanding_loan.to_f
    liquidation_row.to_dollars(liquidation_row.outstanding_loan_cents - repayment_row.outstanding_loan_cents)
  end

  def output_header
    ["Type", "Buy", "Cur.", "Sell", "Cur.", "Fee", "Cur.", "Exchange", "Group", "Comment", "Date"]
  end

  def load_nexo_transactions
    @nexo_transactions = CSV.read(input_path)
    @nexo_transactions.shift # get rid of header
    # ensure oldest transactions are at the beginning. do NOT use #sort because some transactions
    # can have the exact same timestamp and their order will become unpredictable.
    if Date.parse(@nexo_transactions.first[7]) > Date.parse(@nexo_transactions.last[7])
      @nexo_transactions.reverse!
    end
    @nexo_transactions.map! { |nt| InputLine.new(nt) }
  end
end

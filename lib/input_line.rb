class InputLine
  # Represents a line from the Nexo transaction CSV file

  attr_reader :ary

  # HEADER
  # "Transaction", "Type", "Currency", "Amount", "USD Equivalent", "Details", "Outstanding Loan", "Date / Time"

  def initialize(ary)
    @ary = if ary.is_a?(String)
      ary.split(',')
    else
      ary
    end
  end

  def txn_id
    ary[0]
  end

  def original_type
    ary[1].strip
  end
  alias type original_type

  def currency
    cur = ary[2]
    if cur.index("/")
      cur.split("/").map { |x| clean_currency(x.strip) }
    else
      clean_currency(cur)
    end
  end

  def clean_currency(val)
    val = val.to_s.upcase.strip

    case val
    when "USDTERC"
      "USDT"
    when "NEXONEXO"
      "NEXO"
    else
      val
    end
  end

  def amount
    a = ary[3]
    if a.index("/")
      a.split("/").map { |x| x.strip.sub(/\-|\+/, "") }
    else
      a
    end
  end

  def usd_equivalent
    ary[4].strip
  end

  def details
    ary[5]
  end

  def outstanding_loan
    ary[6].strip.sub(/^\$/, '')
  end

  def date
    ary[7]
  end

  def outstanding_loan_cents
    to_cents(outstanding_loan)
  end

  def to_cents(amount_str)
    amount_str = amount_str.to_s unless amount_str.is_a?(String)
    amount_str.sub(/\./, '').to_i
  end

  def to_dollars(amount_str)
    amount_str = amount_str.to_s unless amount_str.is_a?(String)
    return amount_str if amount_str.index('.')
    (amount_str.to_f / 100).to_s
  end

  def amount_is_positive?
    !(amount =~ /^\-/)
  end

  def liquidation?
    original_type == 'Liquidation'
  end

  def repayment?
    original_type == 'Repayment'
  end

  def exchange?
    original_type == 'Exchange'
  end

end
# Financial transactions are the foodcoop's internal financial transactions.
# +Ordergroup+s have an account balance, which is the sum of all their financial transactions.
class FinancialTransaction < ActiveRecord::Base

  # @!attribute amount
  #   @return [Number] Amount credited (negative means debit). May be +nil+ when +payment_amount+ is set.
  # @!attribute note
  #   @return [String] Description of the transaction.

  # @!attribute payment_method
  #   @return [String] Identifier of the payment method (e.g. +manual+, +transfer+, +ideal+, +creditcard+, +paypal+).
  # @!attribute payment_plugin
  #   @return [String] Identifier of the Foodsoft payment plugin (e.g. +mollie+).
  # @!attribute payment_id
  #   @return [String] Identifier at payment provider; when specified, is unique together with +payment_plugin+.
  # @!attribute payment_amount
  #   @return [Number] Amount submitted/paid at payment provider; can be different from +amount+ (e.g. by +payment_fee+).
  # @!attribute payment_currency
  #   @return [String] {https://en.wikipedia.org/wiki/ISO_4217 ISO-4217} currency of +payment_amount+.
  # @!attribute payment_state
  #   Payment status. One of: +created+, +open+, +cancelled+, +paid+, +refunded+, +expired+.
  #   Might be +nil+ for transactions without payment details, in which case it is supposed
  #   to be +paid+.
  #   @return [String] Last known status of payment.
  #   @todo Document payment states, and what happens to this object.
  #   @todo Use a state machine here?
  # @!attribute payment_fee
  #   @return [Number] Fee paid to provider for this transaction.
  # @!attribute payment_acct_number
  #   Account number where payment comes from.
  #   This is dependent on +payment_method+, but there can be overlap between
  #   different methods (e.g. for bank transfer and ideal this is preferably an
  #   IBAN number, but Paypal may have a different identifier).
  #   This, together with +payment_acct_name+, might be used to match payments for
  #   which the ordergroup is not yet known (e.g. bank transfers without a reference number).
  #   @return [String] Account number where payment comes from
  # @!attribute payment_acct_name
  #   @return [String] Account name corresponding to +payment_acct_number+.
  # @!attribute payment_info
  #   @return [String] +payment_plugin+-specific information, stored in YAML.

  # @!attribute ordergroup
  #   @return [Ordergroup] Ordergroup account credited/debited.
  belongs_to :ordergroup
  # @!attribute user
  #   @return [User] User who entered the transaction.
  belongs_to :user

  # @!attribute notify
  #   @return [Boolean] Set this to +false+ to disable sending of account balance notifications.
  #   @note This is a virtual attribute, which is not saved to the database.
  attr_accessor :notify

  # @!attribute hint
  #   @return [String] Optional hint to show when displaying the transaction
  #   @note This is a virtual attribute, which is not saved to the database.
  attr_accessor :hint
  
  validates_presence_of :note, :user_id, :ordergroup_id
  validates_numericality_of :amount, allow_nil: -> { payment_amount.present? }
  validates_numericality_of :payment_amount, :payment_fee, allow_nil: true

  localize_input_of :amount

  after_save :update_ordergroup_balance

  # @!method hide_expired
  #   Scope which hides old transactions that didn't result in a balance change.
  #   @return [Array<FinancialTransaction>] Filtered list
  scope :hide_expired, -> { where("payment_state IS NULL OR payment_state IN ('paid', 'refunded') OR amount > 0 OR amount < 0 OR updated_on > ?", 3.days.ago) }

  # @!method paid
  #   Scope which shows only paid transactions
  #   @see #payment_state
  #   @see #paid?
  #   @return [Array<FinancialTransaction>] Filtered list
  scope :paid, -> { where("payment_state IS NULL OR payment_state = 'paid'") }

  # Positive transaction amount.
  #
  # This is currently any positive amount plus the transaction fee.
  # Returns +nil+ when this transaction has no credit.
  def amount_credit
    if (amount and amount >= 0) or payment_fee
      (amount if amount.to_f >= 0).to_f + payment_fee.to_f
    end
  end

  # Negative transaction amount.
  #
  # This is currently the sum of any negative amount and the transaction fee.
  # Returns +nil+ when this transaction has no debit.
  def amount_debit
    if (amount and amount < 0) or payment_fee
      -(amount if amount.to_f < 0).to_f + payment_fee.to_f
    end
  end

  # Return whether the transaction is paid.
  #
  # Returns +true+ if the transaction has the "paid" state, or if the
  # status is +nil+ for backwards compatibility when no state is being
  # used.
  #
  # If unpaid, the +amount+ should in principle be zero (unless, for example,
  # in a corner case like when a transaction fee is irrevocably levied but it's
  # uncertain whether the amount will be received or not; in that case the
  # amount might be the negative transaction fee, until the payment is
  # received).
  #
  # @see #paid
  # @return [Boolean] Whether the transaction is paid or not
  def paid?
    state.nil? or state == 'paid'
  end

  private
  def update_ordergroup_balance
    # @todo Make sure this transaction and the ordergroup update is in one database transaction.
    #   It may be possible to use an around filter if needed.
    ordergroup.update_balance!(self, notify: self.notify)
  end
end


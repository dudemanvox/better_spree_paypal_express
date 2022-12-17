module Spree
  class PaypalExpressCheckout < Spree::Base
    def actions
      %w{capture credit}
    end

    def can_capture?(payment)
      payment.pending? || payment.checkout?
    end

    def can_credit?(payment)
      payment.completed? && payment.credit_allowed > 0
    end
  end
end
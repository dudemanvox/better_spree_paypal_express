module Spree::RefundDecorator
	private

	# attempts to perform the refund.
  # raises an error if the refund fails.
  def perform!
    return true if transaction_id.present?

    credit_cents = Spree::Money.new(amount.to_f, currency: payment.currency).amount_in_cents

    @response = process!(credit_cents)

    self.transaction_id = @response.try(:authorization) || @response.try(:RefundTransactionID)
    update_columns(transaction_id: transaction_id)
    update_order
  end

	def process!(credit_cents)
		response = if payment.payment_method.is_a? Spree::Gateway::PayPalExpress
                 payment.payment_method.refund(payment, amount)
               elsif payment.payment_method.payment_profiles_supported?
                 payment.payment_method.credit(credit_cents, payment.source, payment.transaction_id, originator: self)
               else
                 payment.payment_method.credit(credit_cents, payment.transaction_id, originator: self)
               end
    Rails.logger.error response.inspect
    unless response.success?
      Rails.logger.error(Spree.t(:gateway_error) + "  #{response.to_yaml}")
      text = (response.try(:params) || {})['message'] ||
             (response.try(:params) || {})['response_reason_text'] ||
             response.try(:message) ||
             response&.errors&.map{|e| e&.long_message}&.to_sentence
      raise Spree::Core::GatewayError, text
    end

    response
  rescue ActiveMerchant::ConnectionError => e
    Rails.logger.error(Spree.t(:gateway_error) + "  #{e.inspect}")
    raise Spree::Core::GatewayError, Spree.t(:unable_to_connect_to_gateway)
  end
end

Spree::Refund.prepend Spree::RefundDecorator
require 'paypal-sdk-merchant'
module Spree
  class Gateway::PayPalExpress < Gateway
    preference :login, :string
    preference :password, :string
    preference :signature, :string
    preference :server, :string, default: 'sandbox'
    preference :solution, :string, default: 'Mark'
    preference :landing_page, :string, default: 'Billing'
    preference :logourl, :string, default: ''

    def supports?(source)
      true
    end

    def provider_class
      ::PayPal::SDK::Merchant::API
    end

    def provider
      ::PayPal::SDK.configure(
        mode:      preferred_server.present? ? preferred_server : "sandbox",
        username:  preferred_login,
        password:  preferred_password,
        signature: preferred_signature,
        ssl_options: { ca_file: nil }
      )
      provider_class.new
    end

    def auto_capture?
      true
    end

    def method_type
      'paypal'
    end

    def purchase(amount, express_checkout, gateway_options={})
      pp_details_request = provider.build_get_express_checkout_details({
        :Token => express_checkout.token
      })
      pp_details_response = provider.get_express_checkout_details(pp_details_request)

      pp_request = provider.build_do_express_checkout_payment({
        :DoExpressCheckoutPaymentRequestDetails => {
          :PaymentAction => "Sale",
          :Token => express_checkout.token,
          :PayerID => express_checkout.payer_id,
          :PaymentDetails => pp_details_response.get_express_checkout_details_response_details.PaymentDetails
        }
      })

      pp_response = provider.do_express_checkout_payment(pp_request)
      if pp_response.success?
        # We need to store the transaction id for the future.
        # This is mainly so we can use it later on to refund the payment if the user wishes.
        transaction_id = pp_response.do_express_checkout_payment_response_details.payment_info.first.transaction_id
        express_checkout.update_column(:transaction_id, transaction_id)
        active_merchant_response_from_paypal(pp_response)
      else
        class << pp_response
          def to_s
            errors.map(&:long_message).join(" ")
          end
        end
        pp_response
      end
    end

    # 
    def refund(payment, amount)
      refund_type = payment.amount == amount.to_f ? "Full" : "Partial"
      refund_transaction = provider.build_refund_transaction({
        :TransactionID => payment.source.transaction_id,
        :RefundType => refund_type,
        :Amount => {
          :currencyID => payment.currency,
          :value => amount },
        :RefundSource => "any" })
      refund_transaction_response = provider.refund_transaction(refund_transaction)
      if refund_transaction_response.success?
        payment.source.update({
          :refunded_at => Time.now,
          :refund_transaction_id => refund_transaction_response.RefundTransactionID,
          :state => "refunded",
          :refund_type => refund_type
        })
      end
      active_merchant_response_from_paypal(refund_transaction_response)
    end

    def active_merchant_response_from_paypal(paypal_response)
      message = if paypal_response.success?
                  "Success"
                else
                  paypal_response.errors.map(&:long_message).join(" ")
                end
      active_merchant_response = ActiveMerchant::Billing::Response.new(
        paypal_response.success?,             # Was the request successful
        message,                              # Message goes here - if we fail, we have errors, else it is blank
        JSON.parse(paypal_response.to_json),  # Params - should be a hash
        {test: preferred_server == "sandbox"} # Keep track of test vs live transactions
      )
    end
  end
end

#   payment.state = 'completed'
#   current_order.state = 'complete'

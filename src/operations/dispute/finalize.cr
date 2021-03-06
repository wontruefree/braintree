class Braintree::Dispute::Finalize < Braintree::Operation
  def initialize(dispute_id)
    @request = HTTP::Request.new(
      method: "PUT",
      resource: "/merchants/#{BT.config.merchant}/disputes/#{dispute_id}/finalize"
    )
  end
end

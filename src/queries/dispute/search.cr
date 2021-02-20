class Braintree::Queries::Dispute::Search < BTQ::Query
  private getter options : Hash(Symbol, String)

  def initialize(@options)
    # TODO: validate and split out cli options
    # TODO: build page info
  end

  def exec
    uri = URI.new
    uri.path = "/merchants/#{BT.config.merchant}/disputes/advanced_search"
    params = URI::Params.new
    params["page"] = options[:page_num]? ? options[:page_num] : "1"
    uri.query_params = params

    response = Braintree.http.post(
      path: uri.request_target,
      body: search_params
    )

    yield response, response.success? ? Models::Disputes.new(XML.parse(response.body)) : nil
  end

  def search_params
    @seach_params ||= XML.build do |xml|
      xml.element("search") do
        amount_disputed_params(xml)
        amount_won_params(xml)
        case_number_params(xml)
        customer_id_params(xml)
        disbursement_date_params(xml)
        effective_date_params(xml)
        dispute_id_params(xml)
        kind_params(xml)
        merchant_account_id_params(xml)
        reason_params(xml)
        reason_code_params(xml)
        reply_by_date_params(xml)
        transaction_id_params(xml)
        status_params(xml)
        transaction_source_params(xml)
      end
    end
  end

  private def amount_disputed_params(xml)
    if disputed_amounts = options[:amount_disputed]?
      xml.element("amount-disputed") do
        if disputed_amounts.includes?(',')
          min, max = disputed_amounts.split(',')
          xml.element("min") { xml.text min } if min
          xml.element("max") { xml.text max } if max
        else
          xml.element("min") { xml.text disputed_amounts }
        end
      end
    end
  end

  private def amount_won_params(xml)
    if won_amounts = options[:amount_won]?
      xml.element("amount-won") do
        if won_amounts.includes?(',')
          min, max = won_amounts.split(',')
          xml.element("min") { xml.text min } if min
          xml.element("max") { xml.text max } if max
        else
          xml.element("min") { xml.text won_amounts }
        end
      end
    end
  end

  private def case_number_params(xml)
    if case_number = options[:case_number]?
      xml.element("case-number") { xml.element("is") { xml.text case_number } }
    end
  end

  private def customer_id_params(xml)
    if customer_id = options[:customer_id]?
      xml.element("customer-id") { xml.element("is") { xml.text customer_id } }
    end
  end

  private def disbursement_date_params(xml)
    if disbursement_dates = options[:disbursement_date]?
      xml.element("disbursement-date") do
        if disbursement_dates.includes?(',')
          min, max = disbursement_dates.split(',')
          xml.element("min") { xml.text min } if min
          xml.element("max") { xml.text max } if max
        else
          xml.element("min") { xml.text disbursement_dates }
        end
      end
    end
  end

  private def effective_date_params(xml)
    if effective_dates = options[:effective_date]?
      xml.element("effective-date") do
        if effective_dates.includes?(',')
          min, max = effective_dates.split(',')
          xml.element("min") { xml.text min } if min
          xml.element("max") { xml.text max } if max
        else
          xml.element("min") { xml.text effective_dates }
        end
      end
    end
  end

  private def dispute_id_params(xml)
    if dispute_id = options[:dispute_id]?
      xml.element("dispute-id") { xml.element("is") { xml.text dispute_id } }
    end
  end

  private def kind_params(xml)
    if options[:kind]?
      kinds = options[:kind].split(",")
      kinds.each do |k|
        raise "invalid kind #{k}" unless BT::Models::Dispute::Kind::ALL.includes?(k)
      end

      xml.element("kind", type: "array") {
        kinds.each { |kind| xml.element("item") { xml.text kind } }
      }
    end
  end

  private def merchant_account_id_params(xml)
    if options[:merchant_account_id]?
      xml.element("merchant-account-id", type: "array") {
        options[:merchant_account_id].split(",") { |id| xml.element("item") { xml.text id } }
      }
    end
  end

  private def reason_params(xml)
    if options[:reason]?
      reasons = options[:reason].split(",")
      reasons.each do |k|
        raise "invalid reason #{k}" unless BT::Models::Dispute::Reason::ALL.includes?(k)
      end

      xml.element("reason", type: "array") {
        reasons.each { |reason| xml.element("item") { xml.text reason } }
      }
    end
  end

  private def reason_code_params(xml)
    if options[:reason_code]?
      codes = options[:reason_code].split(",")

      xml.element("reason-code", type: "array") {
        codes.each { |reason| xml.element("item") { xml.text reason } }
      }
    end
  end

  private def received_date_params(xml)
    if received_dates = options[:received_date]?
      xml.element("received-date") do
        if received_dates.includes?(',')
          min, max = received_dates.split(',')
          xml.element("min") { xml.text min } if min
          xml.element("max") { xml.text max } if max
        else
          xml.element("min") { xml.text received_dates }
        end
      end
    end
  end

  private def reference_number_params(xml)
    if reference_number = options[:reference_number]?
      xml.element("reference-number") { xml.element("is") { xml.text reference_number } }
    end
  end

  private def reply_by_date_params(xml)
    if reply_by_dates = options[:reply_by_date]?
      xml.element("effective-date") do
        if reply_by_dates.includes?(',')
          min, max = reply_by_dates.split(',')
          xml.element("min") { xml.text min } if min
          xml.element("max") { xml.text max } if max
        else
          xml.element("min") { xml.text reply_by_dates }
        end
      end
    end
  end

  private def transaction_id_params(xml)
    if transaction_id = options[:transaction_id]?
      xml.element("transaction-id") { xml.element("is") { xml.text transaction_id } }
    end
  end

  private def status_params(xml)
    if options[:status]?
      statuses = options[:status].split(",")
      statuses.each do |s|
        raise "invalid status #{s}" unless BT::Models::Dispute::Status::ALL.includes?(s)
      end

      xml.element("status", type: "array") {
        statuses.each { |status| xml.element("item") { xml.text status } }
      }
    end
  end

  private def transaction_source_params(xml)
    if options[:transaction_source]?
      sources = options[:transaction_source].split(",")
      sources.each do |s|
        raise "invalid source #{s}" unless BT::Models::Dispute::TransactionSource::ALL.includes?(s)
      end

      xml.element("source", type: "array") {
        sources.each { |source| xml.element("item") { xml.text source } }
      }
    end
  end
end

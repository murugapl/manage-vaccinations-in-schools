# app/components/ops_support/app_associations_table.rb
module OpsSupport
  class AppAssociationsTableComponent < ViewComponent::Base
    # title: The title to display in the card heading (e.g. "Patients" or "Vaccination Records")
    # records: The records to display
    # search_path: URL for the search form submission
    # pagy: Optional pagy object for pagination (if available)

    DISPLAY_MAPPING = {
      "Patients":  "full_name",
      "Vaccination Records":  [:patient,:full_name],
  }.freeze


    def initialize(title:, records:, search_path:)
      @title = title
      @records = records
      @search_path = search_path
    end

    def count
      @records.count
    end

    def display_value(record)
      mapping = DISPLAY_MAPPING[@title.to_sym] || :to_s
      if mapping.is_a?(Array)
        mapping.reduce(record) { |obj, method| obj.send(method) }
      else
        record.send(mapping)
      end
    end
  end
end

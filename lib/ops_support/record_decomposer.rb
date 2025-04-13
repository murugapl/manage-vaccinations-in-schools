# frozen_string_literal: true

module OpsSupport
  class RecordDecomposer
    SKIP_ASSOCIATIONS = {
      "Session" => [:patient_sessions]
      # Add more rules here as: 'OtherType' => [:assoc1, :assoc2]
    }.freeze

    def initialize(object_type:, id:)
      @model_name = object_type
      @id = id.to_i
    end

    # Decomposes the record into its fields:
    #   - attributes: a hash of the record's attributes
    #   - associations: a hash of association names and their fetched values
    #
    # @return [Hash] Decomposed record information or an empty hash if record not found.
    def decompose
      record = find_record
      return {} unless record

      {
        id: record.id,
        object_type: record.class.name,
        attributes: record.attributes,
        associations: fetch_associations(record)
      }
    end

    private

    def find_record
      @model_name.find(@id)
    rescue NameError
      nil
    end

    def fetch_associations(record)
      associations = {}
      skip_list = associations_to_skip(record.class.name)
      record.class.reflect_on_all_associations.each do |assoc|
        next if skip_list.include?(assoc.name)
        associations[assoc.name] = record.send(assoc.name)
      end
      associations
    end

    def associations_to_skip(record_class_name)
      SKIP_ASSOCIATIONS.fetch(record_class_name, [])
    end
  end
end

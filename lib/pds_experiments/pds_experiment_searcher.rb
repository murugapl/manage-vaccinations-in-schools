# frozen_string_literal: true

module PDSExperiments
  class PDSExperimentSearcher
    class << self
      def baseline_search(patient)
        # Fuzzy search with history
        PDS::Patient.search(
          family_name: patient.family_name,
          given_name: patient.given_name,
          date_of_birth: patient.date_of_birth,
          address_postcode: patient.address_postcode
        )
      rescue NHS::PDS::PatientNotFound, NHS::PDS::TooManyMatches
        nil
      end

      def fuzzy_search_without_history(patient)
        query = {
          "family" => patient.family_name,
          "given" => patient.given_name,
          "birthdate" => "eq#{patient.date_of_birth}",
          "address-postalcode" => patient.address_postcode,
          "_fuzzy-match" => true,
          "_history" => false
        }.compact_blank

        results = NHS::PDS.search_patients(query).body
        return nil if results["total"].zero?

        PDS::Patient.send(:from_pds_fhir_response, results["entry"].first["resource"])
      rescue NHS::PDS::TooManyMatches
        raise
      end

      def wildcard_search(patient, include_gender: false, include_history: true)
        given_name_wildcard = patient.given_name&.length&.> 3 ? patient.given_name.first(3) + "*" : patient.given_name
        postcode_wildcard = patient.address_postcode&.length&.> 2 ? patient.address_postcode.first(2) + "*" : patient.address_postcode

        query = {
          "family" => patient.family_name,
          "given" => given_name_wildcard,
          "birthdate" => "eq#{patient.date_of_birth}",
          "address-postalcode" => postcode_wildcard,
          "_fuzzy-match" => false,
          "_history" => include_history
        }

        if include_gender && patient.gender_code.present?
          pds_gender = map_gender_code_to_pds(patient.gender_code)
          query["gender"] = pds_gender if pds_gender
        end

        query.compact_blank!

        results = NHS::PDS.search_patients(query).body
        return nil if results["total"].zero?

        PDS::Patient.send(:from_pds_fhir_response, results["entry"].first["resource"])
      rescue NHS::PDS::TooManyMatches
        raise
      end

      def exact_search(patient, include_history: false)
        query = {
          "family" => patient.family_name,
          "given" => patient.given_name,
          "birthdate" => "eq#{patient.date_of_birth}",
          "address-postalcode" => patient.address_postcode,
          "_exact-match" => true,
          "_history" => include_history
        }.compact_blank

        results = NHS::PDS.search_patients(query).body
        return nil if results["total"].zero?

        PDS::Patient.send(:from_pds_fhir_response, results["entry"].first["resource"])
      rescue NHS::PDS::TooManyMatches
        raise
      end

      private

      def map_gender_code_to_pds(gender_code)
        case gender_code
        when "male"
          "male"
        when "female"
          "female"
        when "not_known"
          "unknown"
        when "not_specified"
          "other"
        else
          nil
        end
      end
    end
  end
end
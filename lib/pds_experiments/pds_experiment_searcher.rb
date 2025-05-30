# frozen_string_literal: true

module PDSExperiments
  class PDSExperimentSearcher
    class << self
      SEARCH_FIELDS = %w[
        _fuzzy-match
        _exact-match
        _history
        _max-results
        family
        given
        gender
        birthdate
        death-date
        email
        phone
        address-postalcode
        general-practitioner
      ].freeze

      GENDER_MAP = {
        "male" => "male",
        "female" => "female",
        "not_known" => "unknown",
        "not_specified" => "other"
      }.freeze

      def baseline_search(patient)
        # Non-fuzzy search with history
        query = {
          "family" => patient.family_name,
          "given" => patient.given_name,
          "birthdate" => "eq#{patient.date_of_birth}",
          "address-postalcode" => patient.address_postcode,
          "_history" => true
        }.compact_blank

        results = search_pds_api(query).body
        if results["total"].zero?
          raise NHS::PDS::PatientNotFound, "No patient found"
        end

        PDS::Patient.send(
          :from_pds_fhir_response,
          results["entry"].first["resource"]
        )
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

        results = search_pds_api(query).body
        if results["total"].zero?
          raise NHS::PDS::PatientNotFound, "No patient found"
        end

        PDS::Patient.send(
          :from_pds_fhir_response,
          results["entry"].first["resource"]
        )
      end

      def fuzzy_search_with_history(patient)
        query = {
          "family" => patient.family_name,
          "given" => patient.given_name,
          "birthdate" => "eq#{patient.date_of_birth}",
          "address-postalcode" => patient.address_postcode,
          "_fuzzy-match" => true,
          "_history" => true
        }.compact_blank

        results = search_pds_api(query).body
        if results["total"].zero?
          raise NHS::PDS::PatientNotFound, "No patient found"
        end

        PDS::Patient.send(
          :from_pds_fhir_response,
          results["entry"].first["resource"]
        )
      end

      def wildcard_search(patient, include_gender: false, include_history: true)
        given_name_wildcard =
          patient.given_name&.length&.>("#{patient.given_name.first(3)}*")
        postcode_wildcard =
          patient.address_postcode&.length&.>(
            "#{patient.address_postcode.first(2)}*"
          )

        query = {
          "family" => patient.family_name,
          "given" => given_name_wildcard,
          "birthdate" => "eq#{patient.date_of_birth}",
          "address-postalcode" => postcode_wildcard,
          "_fuzzy-match" => false,
          "_history" => include_history
        }

        if include_gender && patient.gender_code.present?
          query["gender"] = GENDER_MAP[patient.gender_code]
        end

        query.compact_blank!

        results = search_pds_api(query).body
        if results["total"].zero?
          raise NHS::PDS::PatientNotFound, "No patient found"
        end

        PDS::Patient.send(
          :from_pds_fhir_response,
          results["entry"].first["resource"]
        )
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

        results = search_pds_api(query).body
        if results["total"].zero?
          raise NHS::PDS::PatientNotFound, "No patient found"
        end

        PDS::Patient.send(
          :from_pds_fhir_response,
          results["entry"].first["resource"]
        )
      end

      def cascading_search_1(patient)
        begin
          result = baseline_search(patient)
          return result if result.presence
        rescue NHS::PDS::PatientNotFound
          begin
            result = fuzzy_search_with_history(patient)
            return result if result.presence
          rescue NHS::PDS::TooManyMatches
            result = fuzzy_search_without_history(patient)
            return result if result.presence
          end
        end
        nil
      end

      private

      def search_pds_api(attributes)
        if (missing_attrs = (attributes.keys.map(&:to_s) - SEARCH_FIELDS)).any?
          raise "Unrecognised attributes: #{missing_attrs.join(", ")}"
        end

        response =
          NHS::API.connection.get(
            "personal-demographics/FHIR/R4/Patient",
            attributes
          )

        if is_error?(response, "TOO_MANY_MATCHES")
          raise NHS::PDS::TooManyMatches
        else
          response
        end
      rescue Faraday::BadRequestError
        raise
      end

      def is_error?(error_or_response, code)
        response =
          if error_or_response.is_a?(Faraday::ClientError)
            JSON.parse(error_or_response.response_body)
          elsif error_or_response.is_a?(Faraday::Response)
            error_or_response.body
          end

        return false if (issues = response["issue"]).blank?

        issues.any? do |issue|
          issue["details"]["coding"].any? { |coding| coding["code"] == code }
        end
      end
    end
  end
end

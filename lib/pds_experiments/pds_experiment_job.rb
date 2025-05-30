# frozen_string_literal: true

module PDSExperiments
  class PDSExperimentJob < ApplicationJob
    include NHSAPIConcurrencyConcern

    queue_as :experiments

    def perform(patient, experiment_name, search_strategy)
      begin
        pds_patient = execute_search_strategy(patient, search_strategy)
        
        if pds_patient
          # Success case
          increment_counter(experiment_name, 'total_attempts')
          increment_counter(experiment_name, 'successful_lookups')
          
          # Check for NHS number discrepancy
          if patient.nhs_number.present? && patient.nhs_number != pds_patient.nhs_number
            increment_counter(experiment_name, 'nhs_number_discrepancies')
          end
          
          # Check for data discrepancies
          if patient.family_name != pds_patient.family_name
            increment_counter(experiment_name, 'family_name_discrepancies')
          end
          
          if patient.date_of_birth != pds_patient.date_of_birth
            increment_counter(experiment_name, 'date_of_birth_discrepancies')
          end
          
        else
          # No result case
          increment_counter(experiment_name, 'total_attempts')
          increment_counter(experiment_name, 'no_results')
        end
        
      rescue NHS::PDS::TooManyMatches => e
        increment_counter(experiment_name, 'total_attempts')
        increment_counter(experiment_name, 'too_many_matches_errors')
      rescue => e
        increment_counter(experiment_name, 'total_attempts')
        increment_counter(experiment_name, 'other_errors')
        Rails.logger.error "PDS Experiment error for #{experiment_name}: #{e.message}"
      end
    end

    private

    def execute_search_strategy(patient, strategy)
      case strategy
      when 'baseline'
        PDSExperiments::PDSExperimentSearcher.baseline_search(patient)
      when 'fuzzy_no_history'
        PDSExperiments::PDSExperimentSearcher.fuzzy_search_without_history(patient)
      when 'wildcard_with_history'
        PDSExperiments::PDSExperimentSearcher.wildcard_search(patient, include_history: true)
      when 'wildcard_no_history'
        PDSExperiments::PDSExperimentSearcher.wildcard_search(patient, include_history: false)
      when 'wildcard_gender_with_history'
        PDSExperiments::PDSExperimentSearcher.wildcard_search(patient, include_gender: true, include_history: true)
      when 'wildcard_gender_no_history'
        PDSExperiments::PDSExperimentSearcher.wildcard_search(patient, include_gender: true, include_history: false)
      when 'exact_with_history'
        PDSExperiments::PDSExperimentSearcher.exact_search(patient, include_history: true)
      when 'exact_no_history'
        PDSExperiments::PDSExperimentSearcher.exact_search(patient, include_history: false)
      when 'cascading_search'
        cascading_search(patient)
      else
        raise "Unknown search strategy: #{strategy}"
      end
    end

    def cascading_search(patient)
      strategies = [
        -> { PDSExperiments::PDSExperimentSearcher.baseline_search(patient) },
        -> { PDSExperiments::PDSExperimentSearcher.fuzzy_search_without_history(patient) },
        -> { PDSExperiments::PDSExperimentSearcher.wildcard_search(patient, include_history: false) },
        -> { PDSExperiments::PDSExperimentSearcher.wildcard_search(patient, include_gender: true, include_history: false) }
      ]

      strategies.each do |strategy|
        begin
          result = strategy.call
          return result if result
        rescue NHS::PDS::TooManyMatches 
          next
        end
      end

      nil
    end

    def increment_counter(experiment_name, counter_name)
      cache_key = "pds_experiment:#{experiment_name}:#{counter_name}"
      Rails.cache.increment(cache_key, 1, expires_in: 7.days, initial: 0)
    end
  end
end
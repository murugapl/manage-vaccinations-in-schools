# frozen_string_literal: true

module PDSExperiments
  class PDSExperimentRunner
    EXPERIMENTS = {
      'baseline' => 'baseline',
      'fuzzy_no_history' => 'fuzzy_no_history',
      'wildcard_with_history' => 'wildcard_with_history',
      'wildcard_no_history' => 'wildcard_no_history',
      'wildcard_gender_with_history' => 'wildcard_gender_with_history',
      'wildcard_gender_no_history' => 'wildcard_gender_no_history',
      'exact_with_history' => 'exact_with_history',
      'exact_no_history' => 'exact_no_history',
      'cascading_search' => 'cascading_search'
    }.freeze

    def initialize(patients, experiments: EXPERIMENTS.keys, priority: 10, queue: :experiments)
      @patients = patients
      @experiments = experiments
      @priority = priority
      @queue = queue
    end

    def run_all_experiments
      puts "Starting #{experiments.count} experiments on #{patients.count} patients"
      puts "Experiments: #{experiments.join(', ')}"
      
      experiments.each_with_index do |experiment_name, index|
        puts "\n[#{index + 1}/#{experiments.count}] Starting experiment: #{experiment_name}"
        run_experiment(experiment_name)
        puts "Completed #{patients.count} jobs for #{experiment_name}"
        
        # Add a delay between experiments to avoid overwhelming the system
        if index < experiments.count - 1
          puts "Waiting 10 seconds before next experiment..."
          sleep(10)
        end
      end
      
      puts "\nAll experiments completed successfully!"
      puts "Check results with: PDSExperiments::PDSExperimentRunner.check_progress"
    end

    def run_experiment(experiment_name)
      strategy = EXPERIMENTS[experiment_name]
      raise "Unknown experiment: #{experiment_name}" unless strategy

      # Clear previous results
      clear_experiment_results(experiment_name)

      patients.each_with_index do |patient, index|
        puts "Processing patient #{index + 1}/#{patients.count}: #{patient.id}"
        
        PDSExperiments::PDSExperimentJob.perform_now(patient, experiment_name, strategy)
        
        # Add delay between requests to avoid overwhelming the API
        sleep(wait_between_jobs) if index < patients.count - 1
      end
    end

    def self.run_all(...) = new(...).run_all_experiments
    def self.run_experiment(experiment_name, ...) = new(...).run_experiment(experiment_name)

    def self.check_progress
      puts "=== PDS Experiment Progress ==="
      
      # Check results for each experiment
      EXPERIMENTS.keys.each do |experiment_name|
        total_attempts = Rails.cache.read("pds_experiment:#{experiment_name}:total_attempts") || 0
        successful = Rails.cache.read("pds_experiment:#{experiment_name}:successful_lookups") || 0
        puts "#{experiment_name}: #{total_attempts} attempts, #{successful} successful"
      end
      
      puts "=== End Progress Report ==="
    end

    def self.clear_all_results
      EXPERIMENTS.keys.each do |experiment_name|
        new([]).send(:clear_experiment_results, experiment_name)
      end
      puts "All experiment results cleared"
    end

    private

    attr_reader :patients, :experiments, :priority, :queue

    def wait_between_jobs
      @wait_between_jobs ||= Settings.pds.wait_between_jobs.to_f
    rescue
      @wait_between_jobs ||= 2.0 
    end

    def clear_experiment_results(experiment_name)
      counter_names = %w[
        total_attempts
        successful_lookups
        no_results
        too_many_matches_errors
        other_errors
        nhs_number_discrepancies
        family_name_discrepancies
        date_of_birth_discrepancies
      ]
      
      counter_names.each do |counter_name|
        Rails.cache.delete("pds_experiment:#{experiment_name}:#{counter_name}")
      end
    end
  end
end

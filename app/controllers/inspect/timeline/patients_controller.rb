# frozen_string_literal: true

# app/controllers/inspect/timeline/patients_controller.rb
module Inspect
  module Timeline
    class PatientsController < ApplicationController
      before_action :set_patient
      helper_method :event_options, :reset_filters

      DEFAULT_EVENT_NAMES = ['consents', 'school_moves', 'school_move_log_entries', 'audits', 
                            'patient_sessions', 'triages', 'vaccination_records', 'class_imports', 
                            'cohort_imports', 'vaccination_records'].freeze

      def set_patient
        @patient =
          policy_scope(Patient).find(params[:id])
        @patient_timeline = TimelineRecords.new(@patient.id)
        @patient_events = @patient_timeline.patient_events(@patient)
        @additional_events = @patient_timeline.additional_events(@patient)
      end
      
      def sample_patient(compare_option)
        case compare_option
        when 'class_import'
          class_import = params[:compare_option_class_import]
          Patient.joins(:class_imports).where(class_imports: { id: class_import.id }).where.not(id: @patient.id).sample
        when 'cohort_import'
          cohort_import = params[:compare_option_cohort_import]
          Patient.joins(:cohort_imports).where(cohort_imports: { id: cohort_import.id }).where.not(id: @patient.id).sample
        when 'session'
          session_id = params[:compare_option_session]
          Patient.joins(:patient_sessions).where(patient_sessions: { session_id: session_id }).where.not(id: @patient.id).sample
        when 'manual_entry'
          begin
            Patient.find(params[:manual_patient_id])
          rescue ActiveRecord::RecordNotFound
            return :invalid_patient
          end
        else
          nil
        end
      end

      def event_options
        {
          'consents' => 'Consents',
          'school_moves' => 'School Moves',
          'school_move_log_entries' => 'School Move Log Entries',
          'audits' => 'Audits',
          'patient_sessions' => 'Sessions',
          'triages' => 'Triages',
          'vaccination_records' => 'Vaccination Records',
          'class_imports' => 'Class Imports',
          'cohort_imports' => 'Cohort Imports',
        }
      end

      def show
        # Merge default values into the query parameters if they aren’t present.
        defaults = DEFAULT_EVENT_NAMES
        params.reverse_merge!(event_names: defaults)

        event_names = params[:event_names]
        compare_option = params[:compare_option] || nil

        mermaid = @patient_timeline
                    .generate_timeline(
                      *event_names
                      )
        
        if mermaid.blank?
          @no_events_message = true
        else
          @mermaid_code = mermaid.join("\n")
        end

        if compare_option
          @compare_patient = sample_patient(params[:compare_option])
        end

        if @compare_patient == :invalid_patient
          @invalid_patient_id = true
        elsif @compare_patient
          # Generate timeline for the compare patient
          mermaid_compare = TimelineRecords
                              .new(
                                @compare_patient.id
                                )
                                .generate_timeline(
                                  *event_names
                                  )

          if mermaid_compare.blank?
            @no_events_compare_message = true
          else
            @mermaid_compare_code = mermaid_compare.join("\n")
          end
        end
      end
    end
  end
end

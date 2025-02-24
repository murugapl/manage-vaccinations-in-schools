# frozen_string_literal: true

# app/controllers/inspect/timeline/patients_controller.rb
module Inspect
  module Timeline
    class PatientsController < ApplicationController
      before_action :set_patient
      helper_method :event_options
      def set_patient
        @patient =
          policy_scope(Patient).find(params[:id])
      end
      def event_options
        {
          'consents' => 'Consents',
          'school_moves' => 'School Moves',
          'school_move_log_entries' => 'School Move Log Entries',
          'audits' => 'Audits',
          'patient_sessions' => 'Patient Sessions',
          'triages' => 'Triages',
          'vaccination_records' => 'Vaccination Records',
          'class_imports' => 'Class Imports',
          'cohort_imports' => 'Cohort Imports'
        }
      end
      def show
        event_names = params[:event_names] || ['consents', 'school_moves', 'school_move_log_entries', 'audits', 
'patient_sessions', 'triages', 'vaccination_records', 'class_imports', 'cohort_imports', 'vaccination_records']
        mermaid = TimelineRecords.new(@patient.id).generate_timeline(*event_names)
        
        if mermaid.nil?
          @no_events_message = "No events found for patient with specified filters"
        else
          @mermaid_code = mermaid.join("\n")
        end
        
        render template: 'inspect/timeline/patients/show'
      end
    end
  end
end

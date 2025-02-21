# app/controllers/inspect/timeline/patients_controller.rb
module Inspect
  module Timeline
    class PatientsController < ApplicationController
      before_action :set_patient
      def set_patient
        @patient =
          policy_scope(Patient).find(params[:id])
      end
      def show
        @mermaid_code = TimelineRecords.new(@patient.id).generate_timeline.join("\n")
        render template: 'inspect/timeline/patients/show'
      end
    end
  end
end

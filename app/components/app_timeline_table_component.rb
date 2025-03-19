# frozen_string_literal: true

class AppTimelineTableComponent < ViewComponent::Base
  def initialize(events:, patient_id:, omit_details: false)
    @events = events
    @patient_id = patient_id
    @omit_details = omit_details
  end

  def format_time(date_time)
    date_time.strftime("%H:%M:%S")
  end

  def tag_colour(event_type)
    mapping = {
      "CohortImport"         => "blue",
      "ClassImport"          => "purple",
      "Audit"                => "orange",
      "PatientSession"       => "green",
      "Consent"              => "yellow",
      "Triage"               => "red",
      "VaccinationRecord"    => "grey",
      "SchoolMove"           => "light-blue",
      "SchoolMoveLogEntry"   => "pink"
    }
    mapping.fetch(event_type, "grey")
  end
end

# frozen_string_literal: true

class AppTimelineTableComponent < ViewComponent::Base
  def initialize(events:, patient_id:, omit_details: false)
    @events = events
    @patient_id = patient_id
    @omit_details = omit_details
  end

  def formatted_date(event)
    event[:created_at].strftime("%Y-%m-%d")
  end

  def formatted_time(event)
    event[:created_at].strftime("%H:%M:%S")
  end

  def formatted_details(event)
    if event[:details].is_a?(Hash)
      event[:details].map { |k, v| "#{k}: #{v}" }.join(", ")
    else
      event[:details].to_s
    end
  end

  def tag_colour(event_type)
    mapping = {
      "CohortImport"         => "blue",
      "ClassImport"          => "purple",
      "Audit"                => "orange",
      "Session"              => "green",
      "Consent"              => "yellow",
      "Triage"               => "red",
      "VaccinationRecord"    => "grey",
      "SchoolMove"           => "light-blue",
      "SchoolMoveLogEntry"   => "pink"
    }
    mapping.fetch(event_type, "grey")
  end

  # Group events by date
  def grouped_events
    @events.sort_by { |event| event[:created_at] }
           .group_by { |event| formatted_date(event) }
  end
end

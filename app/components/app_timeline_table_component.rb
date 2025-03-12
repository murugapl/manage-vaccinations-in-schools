# frozen_string_literal: true

# This component is used to render a table of events in the timeline view.
class AppTimelineTableComponent < ViewComponent::Base
  def initialize(events:, patient_id:)
    @events = events
    @patient_id = patient_id
  end

  def formatted_date(event)
    event[:created_at].strftime("%Y-%m-%d")
  end

  def formatted_time(event)
    event[:created_at].strftime("%H:%M:%S")
  end

  def formatted_details(event)
    if event[:details].is_a?(Hash)
      event[:details].map { |k, v| "#{k}=#{v}" }.join(", ")
    else
      event[:details].to_s
    end
  end

  def row_class(event)
    case event[:event_type].downcase
    when 'sessions'
      "nhsuk-table__row--highlight"
    when 'consents'
      "nhsuk-table__row--alert"
    when 'school_move_log_entries'
      "nhsuk-table__row--secondary"
    else
      ""
    end
  end
end

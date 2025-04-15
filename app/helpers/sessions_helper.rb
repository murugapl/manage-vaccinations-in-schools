# frozen_string_literal: true

module SessionsHelper
  def session_consent_period(session, in_sentence:)
    if session.close_consent_at.nil?
      in_sentence ? "not provided" : "Not provided"
    else
      [
        if session.close_consent_at.past?
          in_sentence ? "closed" : "Closed"
        else
          in_sentence ? "open until" : "Open until"
        end,
        session.close_consent_at.to_fs(:long)
      ].join(" ")
    end
  end

  def session_status_tag(session)
    if session.unscheduled?
      govuk_tag(text: "No sessions scheduled", colour: "purple")
    elsif session.completed?
      govuk_tag(text: "All sessions completed", colour: "green")
    else
      govuk_tag(text: "Sessions scheduled", colour: "blue")
    end
  end
end

# frozen_string_literal: true

class EnqueueSchoolConsentRequestsJob < ApplicationJob
  queue_as :notifications

  def perform
    sessions =
      Session.send_consent_requests.joins(:location).merge(Location.school)

    sessions.find_each do |session|
      SendSchoolConsentRequestsJob.perform_later(session)
    end
  end
end

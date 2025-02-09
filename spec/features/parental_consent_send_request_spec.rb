# frozen_string_literal: true

describe "Parental consent" do
  around { |example| travel_to(Date.new(2024, 1, 1)) { example.run } }

  scenario "Send clinic request" do
    given_a_patient_without_consent_exists_in_a_clinic
    and_i_am_signed_in

    when_i_go_to_a_patient_without_consent
    then_i_see_no_requests_sent

    when_i_click_send_consent_request
    then_i_see_the_confirmation_banner
    and_i_see_a_consent_request_has_been_sent
    and_i_do_not_see_a_consent_reminder_button # No consent reminders for clinics
    and_an_email_is_sent_to_the_parent
    and_a_text_is_sent_to_the_parent
    and_an_activity_log_entry_is_visible_for_the_email
    and_an_activity_log_entry_is_visible_for_the_text
  end

  scenario "Send school request and reminders" do
    given_a_patient_without_consent_exists_in_a_school
    and_i_am_signed_in

    when_i_go_to_a_patient_without_consent
    then_i_see_no_requests_sent

    when_i_click_send_consent_request
    then_i_see_the_confirmation_banner
    and_i_see_a_consent_request_has_been_sent
    and_i_see_a_send_reminder_button_instead_of_send_request

    when_i_click_send_reminder
    then_i_see_the_initial_reminder_confirmation_banner
    and_i_see_the_initial_reminder_was_sent
    and_an_initial_reminder_email_is_sent_to_the_parent
    and_a_reminder_text_is_sent_to_the_parent

    when_i_click_send_reminder
    then_i_see_the_subsequent_reminder_confirmation_banner
    and_i_see_the_subsequent_reminder_was_sent
    and_a_subsequent_reminder_email_is_sent_to_the_parent
    and_a_reminder_text_is_sent_to_the_parent

    and_activity_log_entries_are_visible_for_the_reminder_emails
    and_activity_log_entries_are_visible_for_the_reminder_texts
  end

  def given_a_patient_without_consent_exists_in_a_clinic
    programme = create(:programme, :hpv)
    @organisation =
      create(:organisation, :with_one_nurse, programmes: [programme])
    @user = @organisation.users.first

    location = create(:generic_clinic, organisation: @organisation)

    @session =
      create(
        :session,
        organisation: @organisation,
        programme:,
        location:,
        date: Date.current + 2.days
      )

    @parent = create(:parent)
    @patient = create(:patient, session: @session, parents: [@parent])
  end

  def given_a_patient_without_consent_exists_in_a_school
    programme = create(:programme, :hpv)
    @organisation =
      create(:organisation, :with_one_nurse, programmes: [programme])
    @user = @organisation.users.first

    location = create(:school, organisation: @organisation)

    @session =
      create(
        :session,
        organisation: @organisation,
        programme:,
        location:,
        date: Date.current + 2.days
      )

    @parent = create(:parent)
    @patient = create(:patient, session: @session, parents: [@parent])
  end

  def and_i_am_signed_in
    sign_in @user
  end

  def when_i_go_to_a_patient_without_consent
    visit session_consents_path(@session)
    click_link @patient.full_name
  end

  def then_i_see_no_requests_sent
    expect(page).to have_content("No requests have been sent.")
  end

  def when_i_click_send_consent_request
    click_on "Send consent request"
  end

  def then_i_see_the_confirmation_banner
    expect(page).to have_content("Consent request sent.")
  end

  def and_i_see_a_consent_request_has_been_sent
    expect(page).to have_content(
      "No-one responded to our requests for consent."
    )
    expect(page).to have_content("A consent request was sent on")
  end

  def and_an_email_is_sent_to_the_parent
    expect_email_to(@parent.email, :consent_clinic_request)
  end

  def and_a_text_is_sent_to_the_parent
    expect_sms_to(@parent.phone, :consent_clinic_request)
  end

  def and_an_activity_log_entry_is_visible_for_the_email
    click_on "Activity log"
    expect(page).to have_content(
      "Consent clinic request sent\n#{@parent.email}\n" \
        "1 January 2024 at 12:00am · Test User"
    )
  end

  def and_an_activity_log_entry_is_visible_for_the_text
    click_on "Activity log"
    expect(page).to have_content(
      "Consent clinic request sent\n#{@parent.phone}\n" \
        "1 January 2024 at 12:00am · Test User"
    )
  end

  def and_i_do_not_see_a_consent_reminder_button
    expect(page).not_to have_button("Send consent reminder")
    expect(page).to have_button("Send consent request")
  end

  def and_i_see_a_send_reminder_button_instead_of_send_request
    expect(page).not_to have_button("Send consent request")
    expect(page).to have_button("Send consent reminder")
  end

  def when_i_click_send_reminder
    click_on "Send consent reminder"
  end

  def then_i_see_the_initial_reminder_confirmation_banner
    expect(page).to have_content("First consent reminder sent.")
  end

  def then_i_see_the_subsequent_reminder_confirmation_banner
    expect(page).to have_content("Follow-up consent reminder sent.")
  end

  def and_i_see_the_initial_reminder_was_sent
    expect(page).to have_content(
      "No-one responded to our requests for consent."
    )
    expect(page).to have_content("A first consent reminder was sent on")
  end

  def and_i_see_the_subsequent_reminder_was_sent
    expect(page).to have_content(
      "No-one responded to our requests for consent."
    )
    expect(page).to have_content("A follow-up consent reminder was sent on")
  end

  def and_an_initial_reminder_email_is_sent_to_the_parent
    expect_email_to(@parent.email, :consent_school_initial_reminder, :any)
  end

  def and_a_subsequent_reminder_email_is_sent_to_the_parent
    expect_email_to(@parent.email, :consent_school_subsequent_reminder, :any)
  end

  def and_a_reminder_text_is_sent_to_the_parent
    expect_sms_to(@parent.phone, :consent_school_reminder, :any)
  end

  def and_activity_log_entries_are_visible_for_the_reminder_emails
    click_on "Activity log"
    expect(page).to have_content(
      "Consent school initial reminder sent\n#{@parent.email}\n" \
        "1 January 2024 at 12:00am · Test User"
    )
    expect(page).to have_content(
      "Consent school subsequent reminder sent\n#{@parent.email}\n" \
        "1 January 2024 at 12:00am · Test User"
    )
  end

  def and_activity_log_entries_are_visible_for_the_reminder_texts
    click_on "Activity log"
    expect(page).to have_content(
      "Consent school reminder sent\n#{@parent.phone}\n" \
        "1 January 2024 at 12:00am · Test User"
    )
  end
end

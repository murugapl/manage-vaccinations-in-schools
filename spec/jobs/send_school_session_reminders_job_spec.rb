# frozen_string_literal: true

describe SendSchoolSessionRemindersJob do
  subject(:perform_now) { described_class.perform_now }

  let(:programmes) { [create(:programme)] }
  let(:parents) { create_list(:parent, 2) }
  let(:patient) do
    create(:patient, :consent_given_triage_not_needed, parents:, programmes:)
  end

  context "for an active session tomorrow" do
    let!(:session) { create(:session, programmes:, date: Date.tomorrow) }
    let(:patient_session) { create(:patient_session, patient:, session:) }

    it "sends a notification" do
      expect(SessionNotification).to receive(:create_and_send!).once.with(
        patient_session:,
        session_date: Date.tomorrow,
        type: :school_reminder
      )
      perform_now
    end

    context "when triaged for vaccination" do
      let(:patient) do
        create(:patient, :triage_ready_to_vaccinate, parents:, programmes:)
      end

      it "sends a notification" do
        expect(SessionNotification).to receive(:create_and_send!).once.with(
          patient_session:,
          session_date: Date.tomorrow,
          type: :school_reminder
        )
        perform_now
      end
    end

    context "without consent or triage" do
      let(:patient) { create(:patient, parents:) }

      it "doesn't send any notifications" do
        expect(SessionNotification).not_to receive(:create_and_send!)
        perform_now
      end
    end

    context "when already sent" do
      before do
        create(:session_notification, :school_reminder, session:, patient:)
      end

      it "doesn't send any notifications" do
        expect(SessionNotification).not_to receive(:create_and_send!)
        perform_now
      end
    end

    context "when already vaccinated" do
      before do
        create(:vaccination_record, patient:, programme: programmes.first)
      end

      it "doesn't send any notifications" do
        expect(SessionNotification).not_to receive(:create_and_send!)
        perform_now
      end
    end

    context "if the patient is deceased" do
      let(:patient) { create(:patient, :deceased, parents:) }

      it "doesn't send any notifications" do
        expect(SessionNotification).not_to receive(:create_and_send!)
        perform_now
      end
    end

    context "if the patient is invalid" do
      let(:patient) { create(:patient, :invalidated, parents:) }

      it "doesn't send any notifications" do
        expect(SessionNotification).not_to receive(:create_and_send!)
        perform_now
      end
    end

    context "if the patient is restricted" do
      let(:patient) { create(:patient, :restricted, parents:) }

      it "doesn't send any notifications" do
        expect(SessionNotification).not_to receive(:create_and_send!)
        perform_now
      end
    end
  end

  context "for a generic clinic session tomorrow" do
    let(:organisation) { create(:organisation, programmes:) }
    let(:location) { create(:generic_clinic, organisation:) }

    before do
      create(
        :session,
        programmes:,
        date: Date.tomorrow,
        patients: [patient],
        organisation:,
        location:
      )
    end

    it "doesn't send any notifications" do
      expect(SessionNotification).not_to receive(:create_and_send!)
      perform_now
    end
  end

  context "for a session today" do
    before do
      create(:session, programmes:, date: Time.zone.today, patients: [patient])
    end

    it "doesn't send any notifications" do
      expect(SessionNotification).not_to receive(:create_and_send!)
      perform_now
    end
  end

  context "for a session yesterday" do
    before do
      create(:session, programmes:, date: Date.yesterday, patients: [patient])
    end

    it "doesn't send any notifications" do
      expect(SessionNotification).not_to receive(:create_and_send!)
      perform_now
    end
  end
end

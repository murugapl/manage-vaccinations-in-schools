# frozen_string_literal: true

# == Schema Information
#
# Table name: patient_session_registration_statuses
#
#  id                 :bigint           not null, primary key
#  status             :integer          default("unknown"), not null
#  patient_session_id :bigint           not null
#
# Indexes
#
#  idx_on_patient_session_id_438fc21144                   (patient_session_id) UNIQUE
#  index_patient_session_registration_statuses_on_status  (status)
#
# Foreign Keys
#
#  fk_rails_...  (patient_session_id => patient_sessions.id) ON DELETE => cascade
#
describe PatientSession::RegistrationStatus do
  subject(:patient_session_registration_status) do
    build(:patient_session_registration_status, patient_session:)
  end

  let(:programmes) do
    [create(:programme, :menacwy), create(:programme, :td_ipv)]
  end
  let(:patient) { create(:patient, year_group: 9) }
  let(:session) do
    create(:session, dates: [Date.yesterday, Date.current], programmes:)
  end
  let(:patient_session) { create(:patient_session, patient:, session:) }

  it { should belong_to(:patient_session) }

  it do
    expect(patient_session_registration_status).to define_enum_for(
      :status
    ).with_values(%i[unknown attending not_attending completed])
  end

  describe "#status" do
    subject(:status) { patient_session_registration_status.assign_status }

    context "with no session attendance" do
      it { should be(:unknown) }
    end

    context "with a session attendance for a different day to today" do
      before do
        create(
          :session_attendance,
          :present,
          patient_session:,
          session_date: session.session_dates.first
        )
      end

      it { should be(:unknown) }
    end

    context "with a present session attendance for today" do
      before do
        create(
          :session_attendance,
          :present,
          patient_session:,
          session_date: session.session_dates.second
        )
      end

      it { should be(:attending) }
    end

    context "with an absent session attendance for today" do
      before do
        create(
          :session_attendance,
          :absent,
          patient_session:,
          session_date: session.session_dates.second
        )
      end

      it { should be(:not_attending) }
    end

    context "with an outcome for one of the programmes" do
      before do
        create(
          :vaccination_record,
          patient:,
          session:,
          programme: programmes.first
        )
      end

      it { should be(:unknown) }
    end

    context "with an outcome for both of the programmes" do
      before do
        programmes.each do |programme|
          create(:vaccination_record, patient:, session:, programme:)
        end
      end

      it { should be(:completed) }
    end
  end
end

# frozen_string_literal: true

describe Inspect::Timeline::PatientsController do
  describe "#additional_events" do #TODO: make test setup leaner
    let(:programme) { create(:programme) }
    let(:session) { create(:session, programme:) }
    let(:patient) do
      create(
        :patient,
        given_name: "Alex",
        year_group: 8,
        address_postcode: "SW1A 1AA"
      )
    end
    let(:patient_session) { create(:patient_session, patient: patient, session: session) }
    let(:class_imports_with_patient) { create_list(:class_import, 2, session: session) }
    let(:class_imports_without_patient) { create_list(:class_import, 1, session: session) }
    let(:cohort_imports_with_patient) { create_list(:cohort_import, 2, organisation: session.organisation) }
    let(:cohort_imports_without_patient) { create_list(:cohort_import, 1, organisation: session.organisation) }

    before do
      class_imports_without_patient.map { |class_import| class_import.session_id = session.id }
      patient.sessions << session
      patient.class_imports = class_imports_with_patient
      patient.cohort_imports = cohort_imports_with_patient
      patient.organisation.cohort_imports = cohort_imports_with_patient + cohort_imports_without_patient
    end

    context "with class imports" do
      it "returns a hash with class imports and cohort imports" do
        result = described_class.new.additional_events(patient)
        expect(result).to be_a(Hash)
        expect(result.keys).to eq([:class_imports, :cohort_imports])
      end

      it "returns class imports that the patient is not in, for sessions that the patient is in" do
        result = described_class.new.additional_events(patient)
        expect(result[:class_imports]).to be_a(Hash)
        expect(result[:class_imports].keys).to eq([session.id])
        expect(result[:class_imports][session.id]).to eq(class_imports_without_patient.map(&:id))
      end
    end

    context "with cohort imports" do
      it "returns cohort imports that the patient is not in, for organisations that the patient is in" do
        result = described_class.new.additional_events(patient)
        expect(result[:cohort_imports]).to eq(cohort_imports_without_patient.map(&:id))
      end
    end
  end

  describe "#patient_events" do
    let(:programme) { create(:programme) }
    let(:session) { create(:session, programme:) }
    let(:patient) do
      create(
        :patient,
        given_name: "Alex",
        year_group: 8,
        address_postcode: "SW1A 1AA"
      ) end
    let(:patient_session) { create(:patient_session, patient: patient, session: session) }
    let(:class_imports) { create_list(:class_import, 3, session: session) }
    let(:cohort_imports) { create_list(:cohort_import, 3, organisation:session.organisation) }

    before do
      patient.class_imports = class_imports
      patient.cohort_imports = cohort_imports
    end

    context "with class imports" do
      it "returns a hash with class imports, cohort imports, and sessions" do
        result = described_class.new.patient_events(patient)
        expect(result).to be_a(Hash)
        expect(result.keys).to eq([:class_imports, :cohort_imports, :sessions])
      end

      it "returns an array of class import IDs" do
        result = described_class.new.patient_events(patient)
        expect(result[:class_imports]).to eq(class_imports.map(&:id))
      end
    end

    context "with cohort imports" do
      it "returns an array of cohort import IDs" do
        result = described_class.new.patient_events(patient)
        expect(result[:cohort_imports]).to eq(cohort_imports.map(&:id))
      end
    end
  end
end

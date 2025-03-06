describe TimelineRecords do
  let(:programme) { create(:programme, :hpv) }
  let(:organisation) { create(:organisation, programmes: [programme]) }
  let(:session) { create(:session, organisation:, programmes: [programme]) }
  let(:class_import) { create(:class_import, session:) }
  let(:class_import_additional) { create(:class_import, session:) }
  let(:patient) do
    create(
      :patient,
      given_name: "Alex",
      year_group: 8,
      address_postcode: "SW1A 1AA",
      class_imports: [class_import],
      organisation: organisation,
    )
  end
  let(:patient_session) { create(:patient_session, patient: patient, session: session) }
  subject(:timeline) { described_class.new(patient.id) }

  describe '#load_add_class_imports_events' do
    before do
      patient.sessions << session
    end

    it 'returns an array of events' do
      events = timeline.send(:load_events, ["add_class_imports_#{session.id}"])
      expect(events).to be_an Array
    end

    it 'includes the class import event' do
      events = timeline.send(:load_events, ["add_class_imports_#{session.id}"])
      expect(events.size).to eq 1
      event = events.first
      expect(event[:event_type]).to eq 'patient_class_import'
      expect(event[:id]).to eq class_import.id
      expect(event[:details]).to eq 'excluding patient'
      expect(event[:created_at]).to eq class_import.created_at
    end

    it 'handles multiple additional class imports' do
      class_import additional_2 = create(:class_import, session:, created_at: 1.minute.from_now)
      session.class_imports << class_import_additional_2
      events = timeline.send(:load_events, ["add_class_imports_#{session.id}"])
      expect(events.size).to eq 2
      expect(events.map { |event| event[:id] }).to contain_exactly(class_import.id, another_class_import.id)
    end

    it 'handles no additional class imports' do
      session.class_imports = [class_import] #no import excluding patient
      events = timeline.send(:load_events, ["add_class_imports_#{session.id}"])
      expect(events).to be_empty
    end

    it 'handles a nil session id' do
      events = timeline.send(:load_events, ["add_class_imports_nil"])
      expect(events).to be_empty
    end
  end

  describe "#additional_events" do
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
        result = timeline.additional_events(patient)
        expect(result).to be_a(Hash)
        expect(result.keys).to eq([:class_imports, :cohort_imports])
      end

      it "returns class imports that the patient is not in, for sessions that the patient is in" do
        result = timeline.additional_events(patient)
        expect(result[:class_imports]).to be_a(Hash)
        expect(result[:class_imports].keys).to eq([session.id])
        expect(result[:class_imports][session.id]).to eq(class_imports_without_patient.map(&:id))
      end
    end

    context "with cohort imports" do
      it "returns cohort imports that the patient is not in, for organisations that the patient is in" do
        result = timeline.additional_events(patient)
        expect(result[:cohort_imports]).to eq(cohort_imports_without_patient.map(&:id))
      end
    end
  end

  describe "#patient_events" do
    let(:class_imports) { create_list(:class_import, 3, session: session) }
    let(:cohort_imports) { create_list(:cohort_import, 3, organisation: session.organisation) }

    before do
      patient.class_imports = class_imports
      patient.cohort_imports = cohort_imports
    end

    context "with class imports" do
      it "returns a hash with class imports, cohort imports, and sessions" do
        result = timeline.patient_events(patient)
        expect(result).to be_a(Hash)
        expect(result.keys).to eq([:class_imports, :cohort_imports, :sessions])
      end

      it "returns an array of class import IDs" do
        result = timeline.patient_events(patient)
        expect(result[:class_imports]).to eq(class_imports.map(&:id))
      end
    end

    context "with cohort imports" do
      it "returns an array of cohort import IDs" do
        result = timeline.patient_events(patient)
        expect(result[:cohort_imports]).to eq(cohort_imports.map(&:id))
      end
    end
  end
end

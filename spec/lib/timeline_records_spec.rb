# frozen_string_literal: true

describe TimelineRecords do
  subject(:timeline) { described_class.new(patient.id, patient_info, additional_events) } #TODO: Make test setup leaner

  let!(:programme) { create(:programme, :hpv) }
  let!(:organisation) { create(:organisation, programmes: [programme]) }
  let!(:session) { create(:session, organisation:, programmes: [programme]) }
  let!(:class_import) { create(:class_import, session:) }
  let!(:patient) { create(:patient, sessions: [session], class_imports: [class_import], organisation: organisation) }
  let(:patient_info) { { class_imports: [class_import.id], cohort_imports: [], sessions: [session.id] } }
  let(:additional_events) { { class_imports: { session.id => [class_import.id] }, cohort_imports: [] } }

  before do
    additional_events[:class_imports][session.id] = [class_import.id]
  end

  describe '#load_add_class_imports_events' do
    it 'returns an array of events' do
      events = timeline.send(:load_events,["add_class_imports_#{session.id}"])
      expect(events).to be_an Array
    end

    it 'includes the class import event' do
      events = timeline.send(:load_events,["add_class_imports_#{session.id}"])
      expect(events.size).to eq 1 
      event = events.first
      expect(event[:event_type]).to eq 'patient_class_import'
      expect(event[:id]).to eq class_import.id
      expect(event[:details]).to eq 'excluding patient'
      expect(event[:created_at]).to eq class_import.created_at
    end

    it 'handles multiple class imports' do
      another_class_import = create(:class_import, session:, created_at: 1.minute.from_now)
      additional_events[:class_imports][session.id] << another_class_import.id
      events = timeline.send(:load_events,["add_class_imports_#{session.id}"])
      expect(events.size).to eq 2
      expect(events.map { |event| event[:id] }).to contain_exactly(class_import.id, another_class_import.id)
    end

    it 'handles an empty array of class imports' do
      additional_events[:class_imports][session.id] = []
      events = timeline.send(:load_events,["add_class_imports_#{session.id}"])
      expect(events).to be_empty
    end

    it 'handles a nil session id' do
      events = timeline.send(:load_events,["add_class_imports_nil"])
      expect(events).to be_empty
    end
  end
end

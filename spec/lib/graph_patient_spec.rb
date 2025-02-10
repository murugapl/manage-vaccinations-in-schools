describe GraphPatient do
  it "should return a flowchart" do
    programme = create(:programme, :hpv)
    organisation = create(:organisation, programmes: [programme])
    session = create(:session, organisation:, programmes: [programme])
    class_import = create(:class_import, session:)
    parent = create(:parent, class_imports: [class_import])
    patient =
      create(
        :patient,
        parents: [parent],
        session:,
        organisation:,
        programme:,
        class_imports: [class_import]
      )
    consent =
      create(:consent, :given, patient:, parent:, organisation:, programme:)
    parent = patient.parents.first

    graph = described_class.new(patient, include_class_imports: true).call

    expected = [
      "flowchart TB",
      "  classDef patient fill:#c2e598",
      "  classDef parent fill:#faa0a0",
      "  classDef consent fill:#fffaa0",
      "  classDef class_import fill:#7fd7df",
      "  classDef patient_highlighted fill:#c2e598,stroke:#000,stroke-width:3px",
      "  classDef parent_highlighted fill:#faa0a0,stroke:#000,stroke-width:3px",
      "  patient-#{patient.id}:::patient_highlighted",
      "  patient-#{patient.id}:::patient_highlighted --> parent-#{parent.id}:::parent",
      "  parent-#{parent.id}:::parent",
      "  consent-#{consent.id}:::consent --> parent-#{parent.id}:::parent",
      "  class_import-#{class_import.id}:::class_import --> parent-#{parent.id}:::parent",
      "  patient-#{patient.id}:::patient_highlighted --> consent-#{consent.id}:::consent",
      "  class_import-#{class_import.id}:::class_import --> patient-#{patient.id}:::patient_highlighted"
    ]
    graph.flatten.each_with_index do |line, index|
      expect(line).to eq(expected[index])
    end
  end
end

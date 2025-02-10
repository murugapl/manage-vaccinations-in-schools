# frozen_string_literal: true

class GraphPatient
  def initialize(
    *patients,
    parents: [],
    include_consents: true,
    include_class_imports: false,
    highlight_patients: [],
    highlight_parents: []
  )
    @patients = patients.map { it.is_a?(Patient) ? it : Patient.find(it) }
    @parents = parents.map { it.is_a?(Parent) ? it : Parent.find(it) }
    @include_consents = include_consents
    @include_class_imports = include_class_imports
    @highlight_patients =
      @patients +
        Array(highlight_patients).map! do |it|
          it.is_a?(Patient) ? it : Patient.find(it)
        end
    @highlight_parents =
      @parents +
        Array(highlight_parents).map! do |it|
          it.is_a?(Parent) ? it : Parent.find(it)
        end

    @visited_patients = []
    @visited_parents = []
  end

  def call
    ["flowchart TB"] + styles + @patients.flat_map { patient_graph(it) } +
      @parents.flat_map { parent_graph(it) }
  end

  def styles
    [
      "  classDef patient fill:#c2e598",
      "  classDef parent fill:#faa0a0",
      "  classDef consent fill:#fffaa0",
      "  classDef class_import fill:#7fd7df",
      "  classDef patient_highlighted fill:#c2e598,stroke:#000,stroke-width:3px",
      "  classDef parent_highlighted fill:#faa0a0,stroke:#000,stroke-width:3px"
    ]
  end

  def patient_graph(patient)
    return [] if @visited_patients.include?(patient)

    @visited_patients << patient

    node = patient_node(patient)
    parents = patient.parents.includes(:consents, :class_imports)
    parent_connections =
      parents.flat_map do
        ["  #{node} --> #{parent_node(it)}"] + parent_graph(it)
      end

    ["  #{node}"] + parent_connections + consent_connections(patient) +
      class_imports_connections(patient)
  end

  def parent_graph(parent)
    return [] if @visited_parents.include?(parent)

    @visited_parents << parent

    patients = parent.patients.includes(:parents, :class_imports)
    patient_connections = patients.flat_map { patient_graph(it) }

    ["  #{parent_node(parent)}"] + patient_connections +
      consent_connections(parent) + class_imports_connections(parent)
  end

  def patient_node(patient)
    "patient-#{patient.id}:::#{class_for_patient(patient)}"
  end

  def parent_node(parent)
    "parent-#{parent.id}:::#{class_for_parent(parent)}"
  end

  def consent_node(consent)
    "consent-#{consent.id}:::#{class_for_consent(consent)}"
  end

  def class_import_node(class_import)
    "class_import-#{class_import.id}:::#{class_for_class_import(class_import)}"
  end

  def consent_connections(obj)
    return [] unless @include_consents

    case obj
    when Patient
      obj_node = patient_node(obj)
      obj.consents.map { "  #{obj_node} --> #{consent_node(it)}" }
    when Parent
      obj_node = parent_node(obj)
      obj.consents.map { "  #{consent_node(it)} --> #{obj_node}" }
    end
  end

  def class_imports_connections(obj)
    return [] unless @include_class_imports

    obj_node =
      case obj
      when Patient
        patient_node(obj)
      when Parent
        parent_node(obj)
      end
    obj.class_imports.map { "  #{class_import_node(it)} --> #{obj_node}" }
  end

  def class_for_patient(patient)
    @highlight_patients.include?(patient) ? "patient_highlighted" : "patient"
  end

  def class_for_parent(parent)
    @highlight_parents.include?(parent) ? "parent_highlighted" : "parent"
  end

  def class_for_consent(_consent)
    "consent"
  end

  def class_for_class_import(_class_import)
    "class_import"
  end
end

# frozen_string_literal: true

class GraphPatient
  def initialize(
    *patients,
    parents: [],
    show_consents: true,
    show_class_imports: true,
    show_cohort_imports: true,
    focus_patients: [],
    focus_parents: []
  )
    @patients = patients.map { it.is_a?(Patient) ? it : Patient.find(it) }
    @parents = parents.map { it.is_a?(Parent) ? it : Parent.find(it) }
    @show_consents = show_consents
    @show_class_imports = show_class_imports
    @show_cohort_imports = show_cohort_imports
    @focus_patients =
      @patients +
        Array(focus_patients).map! do |it|
          it.is_a?(Patient) ? it : Patient.find(it)
        end
    @focus_parents =
      @parents +
        Array(focus_parents).map! do |it|
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
      "  classDef cohort_import fill:#a2d2ff",
      "  classDef patient_focused fill:#c2e598,stroke:#000,stroke-width:3px",
      "  classDef parent_focused fill:#faa0a0,stroke:#000,stroke-width:3px"
    ]
  end

  def patient_graph(patient)
    return [] if @visited_patients.include?(patient)

    @visited_patients << patient

    node = patient_node(patient)
    parents =
      patient.parents.includes(:consents, :class_imports, :cohort_imports)
    parent_connections =
      parents.flat_map do
        ["  #{node} --> #{parent_node(it)}"] + parent_graph(it)
      end

    ["  #{node}"] + parent_connections + consent_connections(patient) +
      class_imports_connections(patient) + cohort_imports_connections(patient)
  end

  def parent_graph(parent)
    return [] if @visited_parents.include?(parent)

    @visited_parents << parent

    patients =
      parent.patients.includes(:parents, :class_imports, :cohort_imports)
    patient_connections = patients.flat_map { patient_graph(it) }

    ["  #{parent_node(parent)}"] + patient_connections +
      consent_connections(parent) + class_imports_connections(parent) +
      cohort_imports_connections(parent)
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

  def node_text(obj)
    klass = obj.class.name.underscore
    diagram_class_name = class_text_for_obj(obj)
    "#{klass}-#{obj.id}:::#{diagram_class_name}"
  end

  def consent_connections(obj)
    return [] unless @show_consents

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
    return [] unless @show_class_imports

    obj_node =
      case obj
      when Patient
        patient_node(obj)
      when Parent
        parent_node(obj)
      end
    obj.class_imports.map { "  #{class_import_node(it)} --> #{obj_node}" }
  end

  def cohort_imports_connections(obj)
    return [] unless @show_cohort_imports

    obj_node =
      case obj
      when Patient
        patient_node(obj)
      when Parent
        parent_node(obj)
      end
    obj.cohort_imports.map { "  #{node_text(it)} --> #{obj_node}" }
  end

  def class_for_patient(patient)
    @focus_patients.include?(patient) ? "patient_focused" : "patient"
  end

  def class_for_parent(parent)
    @focus_parents.include?(parent) ? "parent_focused" : "parent"
  end

  def class_for_consent(_consent)
    "consent"
  end

  def class_for_class_import(_class_import)
    "class_import"
  end

  def class_text_for_obj(obj)
    obj.class.name.underscore
  end
end

# frozen_string_literal: true

class GraphPatient
  def initialize(
    *patient_ids,
    parents: [],
    show_consents: true,
    show_class_imports: true,
    show_cohort_imports: true,
    focus_patients: [],
    focus_parents: []
  )
    @patient_ids = patient_ids
    @parent_ids = parents
    @show_associations = {
      class_imports: show_class_imports,
      cohort_imports: show_cohort_imports,
      consents: show_consents,
      patients: true,
      parents: true
    }
    @focus_objects =
      patients +
        Array(focus_patients).map! do |it|
          it.is_a?(Patient) ? it : Patient.find(it)
        end + parents +
        Array(focus_parents).map! do |it|
          it.is_a?(Parent) ? it : Parent.find(it)
        end

    @nodes = Set.new
    @edges = Set.new
  end

  def patients
    @patients ||= Patient.where(id: @patient_ids)
  end

  def parents
    @parents ||= Parent.where(id: @parent_ids)
  end

  def call
    custom_patients_association(self).each do |patient|
      @nodes << patient
      introspect_patients(patient)
    end

    custom_parents_association(self).each do |parent|
      @nodes << parent
      introspect_parent(parent)
    end

    ["flowchart TB"] + styles + render_nodes + render_edges
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

  def render_nodes
    @nodes.to_a.map { "  #{node_with_class(it)}" }
  end

  def reverse_nodes?(from, to)
    [
      [Patient, ClassImport],
      [Patient, CohortImport],
      [Parent, ClassImport],
      [Parent, CohortImport],
      [Parent, Consent],
      [Parent, Patient]
    ].include?([from.class, to.class])
  end

  def render_edges
    @edges.map { |from, to| "  #{node_name(from)} --> #{node_name(to)}" }
  end

  def collect_association(obj, association)
    return unless @show_associations[association]

    records =
      if respond_to?("custom_#{association}_association")
        send("custom_#{association}_association", obj)
      else
        obj.send(association)
      end

    records.each do
      @edges << (reverse_nodes?(obj, it) ? [it, obj] : [obj, it])

      if respond_to?("introspect_#{association}")
        next if @nodes.include?(it)
        @nodes << it
        send("introspect_#{association}", it)
      else
        @nodes << it
      end
    end
  end

  def introspect_patients(patient)
    collect_association(patient, :parents)
    collect_association(patient, :consents)
    collect_association(patient, :class_imports)
    collect_association(patient, :cohort_imports)
  end

  def introspect_parents(parent)
    collect_association(parent, :patients)
    collect_association(parent, :consents)
    collect_association(parent, :class_imports)
    collect_association(parent, :cohort_imports)
  end

  def custom_parents_association(obj)
    obj.parents.includes(:consents, :class_imports, :cohort_imports)
  end

  def custom_patients_association(obj)
    obj.patients.includes(:parents, :class_imports, :cohort_imports)
  end

  def node_name(obj)
    klass = obj.class.name.underscore
    "#{klass}-#{obj.id}"
  end

  def node_with_class(obj)
    "#{node_name(obj)}:::#{class_text_for_obj(obj)}"
  end

  def class_text_for_obj(obj)
    obj.class.name.underscore + (obj.in?(@focus_objects) ? "_focused" : "")
  end
end

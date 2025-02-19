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
    @inspected = Set.new
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
      inspect(patient)
    end

    custom_parents_association(self).each do |parent|
      @nodes << parent
      inspect(parent)
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

  def inspect(obj)
    return unless inspect_class?(obj)

    return if @inspected.include?(obj)
    @inspected << obj

    association_types = obj.class.reflect_on_all_associations.map(&:name)
    association_types.each { collect_association(obj, it) }
  end

  def collect_association(obj, association_name)
    return unless @show_associations[association_name]

    associated =
      if respond_to?("custom_#{association_name}_association")
        send("custom_#{association_name}_association", obj)
      else
        obj.send(association_name)
      end

    associated.each do
      @nodes << it
      @edges << (reverse_nodes?(obj, it) ? [it, obj] : [obj, it])

      inspect(it)
    end
  end

  # TODO: This should be configurable
  def inspect_class?(record)
    record.class.name.in?(%w[Patient Parent])
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

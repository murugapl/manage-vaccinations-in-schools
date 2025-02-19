# frozen_string_literal: true

class GraphPatient
  def initialize(
    *patient_ids,
    parents: [],
    show_consents: true,
    show_class_imports: true,
    show_cohort_imports: true,
    focus_patients: [],
    focus_parents: [],
    node_order: %i[class_import cohort_import patient consent parent]
  )
    @patient_ids = patient_ids
    @parent_ids = parents
    @focus_objects =
      patients +
        Array(focus_patients).map! do |it|
          it.is_a?(Patient) ? it : Patient.find(it)
        end + parents +
        Array(focus_parents).map! do |it|
          it.is_a?(Parent) ? it : Parent.find(it)
        end
    @node_order = node_order
    @inspection_list = {
      patient: %i[parents consents class_imports cohort_imports],
      parent: %i[consents class_imports cohort_imports]
    }

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
    associated_patients_objects(self).each do |patient|
      @nodes << patient
      inspect(patient)
    end

    associated_parents_objects(self).each do |parent|
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

  def order_nodes(*nodes)
    nodes.sort_by { @node_order.index(it.class.name.underscore.to_sym) }
  end

  def render_edges
    @edges.map { |from, to| "  #{node_name(from)} --> #{node_name(to)}" }
  end

  def inspect(obj)
    associations_list = @inspection_list[obj.class.name.underscore.to_sym]
    return unless associations_list.present?

    return if @inspected.include?(obj)
    @inspected << obj

    associations_list.each do
      get_associated_objects(obj, it).each do
        @nodes << it
        @edges << order_nodes(obj, it)

        inspect(it)
      end
    end
  end

  def get_associated_objects(obj, association_name)
    if respond_to?("associated_#{association_name}_objects")
      send("associated_#{association_name}_objects", obj)
    else
      obj.send(association_name)
    end
  end

  def inspect_class?(record)
    @inspection_list[record.class.name.underscore.to_sym]
  end

  def associated_parents_objects(base)
    base.parents.includes(:consents, :class_imports, :cohort_imports)
  end

  def associated_patients_objects(base)
    base.patients.includes(:parents, :class_imports, :cohort_imports)
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

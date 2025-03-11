# frozen_string_literal: true

class TimelineRecords
  def initialize(patient_id, detail_config: {})
    @patient = Patient.find(patient_id)
    @patient_id = patient_id
    @patient_events = patient_events(@patient)
    @additional_events = additional_events(@patient)
    @detail_config = detail_config
    @events = []
  end

  def generate_timeline(*event_names)
    load_events(event_names)
    format_timeline
  end

  def generate_timeline_console(*event_names)
    load_events(event_names)
    format_timeline_json
  end

  def additional_events(patient)
    patient_imports = patient_events(patient)[:class_imports]
    class_imports = ClassImport.where(session_id: patient_events(patient)[:sessions])
    class_imports = class_imports.where.not(id: patient_imports) if patient_imports.present?
    {
      class_imports: class_imports.group_by(&:session_id).transform_values { |imports| imports.map(&:id) },
      cohort_imports: patient.organisation.cohort_imports
                        .reject { 
                          |ci| patient_events(patient)[:cohort_imports].include?(ci.id) 
                        }
                        .map(&:id)
    }
  end

  def patient_events(patient)
  {
    class_imports: patient.class_imports.map(&:id),
    cohort_imports: patient.cohort_imports.map(&:id),
    sessions: patient.sessions.map(&:id)
  }
  end

  def details
    @details ||= {
      audits: %i[action audited_changes],
      cohort_imports: %i[],
      class_imports: %i[],
      sessions: %i[location_id],
      school_moves: %i[school_id source],
      school_move_log_entries: %i[school_id user_id],
      consents: %i[response route],
      triages: %i[status performed_by_user_id],
      vaccination_records: %i[outcome session_id],
  }.merge(@detail_config)
  end

  private

  def load_events(event_names)
    event_names.each do |event_name|
      event_type = event_name.to_sym
  
      if details.key?(event_type)
        fields = details[event_type]
        records = @patient.send(event_type)
        records = Array(records)
  
        records.each do |record|
          event_details = fields.map { |field| [field.to_s.capitalize, record.send(field)] }.to_h
          @events << {
            event_type: event_type.to_s.capitalize,
            id: record.id,
            details: event_details,
            created_at: record.created_at
          }
        end
      else
        # Call a custom function for event types not in details
        custom_event_handler(event_type)
      end
    end
    @events.sort_by! { |event| event[:created_at] }
  end 

  def custom_event_handler(event_type)
    case event_type
    when :org_cohort_imports
      @events += org_cohort_imports_events
    when /^add_class_imports_\d+$/ # e.g. add_class_imports_123
      session_id = event_type.to_s.split('_').last
      @events += add_class_imports_events(session_id)
    else
      puts "No handler for event type: #{event_type}"
    end
  end

  def org_cohort_imports_events
    @additional_events[:cohort_imports].map do |cohort_import_id|
      cohort_import = CohortImport.find(cohort_import_id)
      {
        event_type: 'cohort_import',
        id: cohort_import.id,
        details: "excluding patient",
        created_at: cohort_import.created_at
      }
    end
  end

  def add_class_imports_events(session_id)
    @additional_events[:class_imports][session_id.to_i].map do |class_import_id|
      class_import = ClassImport.find(class_import_id)
      { 
        event_type: 'class_import',
        id: class_import.id,
        details: "excluding patient",
        created_at: class_import.created_at.to_time
      }
    end
  end

  def format_timeline
    timeline = ["timeline", "title Timeline for Patient-#{@patient_id}"]
    current_date = nil
    current_time = nil
    stacked_events = []
  
    @events.each do |event|
      event_date = event[:created_at].strftime('%Y-%m-%d')
      event_time = event[:created_at].strftime('%H-%M-%S')
  
      if event_date != current_date
        # Output any stacked events before starting a new section
        unless stacked_events.empty?
          timeline << "        #{current_time} : #{stacked_events.join(' : ')}"
          stacked_events.clear
        end
  
        timeline << "    section #{event_date}"
        current_date = event_date
      end
  
      if event_time != current_time
        # Output any stacked events before starting a new time
        unless stacked_events.empty?
          timeline << "        #{current_time} : #{stacked_events.join(' : ')}"
          stacked_events.clear
        end
  
        current_time = event_time
      end
  
      event_description = format_event_description(event)
      stacked_events << event_description
    end
  
    # Output any remaining stacked events
    unless stacked_events.empty?
      timeline << "        #{current_time} : #{stacked_events.join(' : ')}"
    end
  
  end

  def format_event_description(event)
    details_string = event[:details].is_a?(Hash) ? event[:details].map { |key, value| "#{key}; #{value}" }.join("<br> ") : event[:details]
    "#{event[:event_type]}-#{event[:id]}<br> #{details_string}"
  end

  def format_timeline_json
    timeline = []
    @events.each do |event|
      event_hash = {
        date: event[:created_at].strftime('%Y-%m-%d'),
        time: event[:created_at].strftime('%H:%M:%S'),
        event_type: event[:event_type],
        id: event[:id],
        details: event[:details]
      }
      timeline << event_hash
    end
    JSON.pretty_generate(timeline)
  end
end

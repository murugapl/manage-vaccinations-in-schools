# frozen_string_literal: true

class TimelineRecords
  DEFAULT_DETAILS_CONFIG = {
      audits: %i[action audited_changes],
      cohort_imports: [],
      class_imports: [],
      sessions: %i[location_id],
      school_moves: %i[school_id source],
      school_move_log_entries: %i[school_id user_id],
      consents: %i[response route],
      triages: %i[status performed_by_user_id],
      vaccination_records: %i[outcome session_id]
    }.freeze

  def initialize(patient_id, detail_config: {})
    @patient = Patient.find(patient_id)
    @patient_id = patient_id
    @patient_events = patient_events(@patient)
    @additional_events = additional_events(@patient)
    @detail_config = extract_detail_config(detail_config)
    @events = []
  end

  def generate_timeline_console(*event_names, truncate_columns: true)
    load_events(event_names)
    format_timeline_console(truncate_columns)
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

  def extract_detail_config(detail_config)
    detail_config.deep_symbolize_keys
  end

  def details
    @details ||= DEFAULT_DETAILS_CONFIG.merge(@detail_config)
  end

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

  private

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

  def format_timeline_console(truncate_columns)
    # Increase field widths as needed.
    event_type_width = 25
    details_width = 50
    header_format = if truncate_columns
                      "%-12s %-10s %-#{event_type_width}s %-12s %-#{details_width}s"
                    else
                      "%-12s %-10s %-20s %-10s %-s"
                    end 
    puts sprintf(header_format, "DATE", "TIME", "EVENT_TYPE", "EVENT-ID", "DETAILS")
    puts "-" * 115
    
    @events.each do |event|
      date = event[:created_at].strftime('%Y-%m-%d')
      time = event[:created_at].strftime('%H:%M:%S')
      event_type = event[:event_type].to_s.ljust(25)[0...25]
      event_id = event[:id].to_s
      details_string = if event[:details].is_a?(Hash)
                         event[:details].map { |k, v| "#{k}=#{v}" }.join(", ")
                       else
                         event[:details].to_s
                       end
      if truncate_columns
        event_type = event_type.ljust(event_type_width)[0...event_type_width]
        details    = details_string.ljust(details_width)[0...details_width]
      else
        details    = details_string
      end
      
      puts sprintf(header_format, date, time, event_type, event_id, details)
    end
    nil
  end  
end

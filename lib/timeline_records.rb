# frozen_string_literal: true

class TimelineRecords
  def initialize(patient_id)
    @patient = Patient.find(patient_id)
    @patient_id = patient_id
    @patient_events = patient_events(@patient)
    @additional_events = additional_events(@patient)
    @events = []
  end

  def generate_timeline(*event_names)
    load_events(event_names)
    format_timeline
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

  private

  def load_events(event_names)
    event_sources.each do |source|
      if event_names.include?(source.to_s)
        @events += respond_to?("#{source}_events", true) ? send("#{source}_events") : generic_events(source.to_s)
      end
    end
    event_names.select { |event| event.start_with?('add_class_imports') }.each do |event|
      session_id = event.split('_').last.to_i
      @events += add_class_imports_events(session_id) if session_id.positive?
    end
    @events.sort_by! { |event| event[:created_at] }
  end

  def event_sources
    %i[audits consents school_moves school_move_log_entries patient_sessions triages vaccination_records class_imports 
cohort_imports org_cohort_imports]
  end

  def generic_events(event)
    events = @patient.send(event)
    return [] if events.nil?

    events.map do |e|
      {
        event_type: "generic",
        id: e.id,
        details: event.to_s,
        created_at: e.created_at
      }
    end
  end

  def audits_events
    @patient.audits.map do |audit|
      {
        event_type: audit.action,
        details: audit.audited_changes,
        created_at: audit.created_at
      }
    end
  end

  def consents_events
    @patient.consents.map do |consent|
      {
        event_type: 'consent',
        id: consent.id,
        details: "#{consent.response} via #{consent.route}",
        created_at: consent.created_at
      }
    end
  end

  def school_moves_events
    @patient.school_moves.map do |move|
      {
        event_type: 'school_move',
        id: move.id,
        details: "to #{move.school_id.nil? ? @patient.organisation.generic_clinic_session.location.name : Location.find(move.school_id).name} due to #{move.source}",
        created_at: move.created_at
      }
    end
  end

  def school_move_log_entries_events
    @patient.school_move_log_entries.map do |move|
      {
        event_type: 'school_move_log',
        id: move.id,
        details: "to #{move.school_id.nil? ? @patient.organisation.generic_clinic_session.location.name : Location.find(move.school_id).name}" +
         (move.user_id.nil? ? "" : " performed by User-#{move.user_id}"),
        created_at: move.created_at
      }
    end
  end

  def patient_sessions_events
    @patient_events[:sessions].map do |session_id|
      session = Session.find(session_id)
      {
        event_type: 'session',
        id: session_id,
        details: session.location.name.to_s,
        created_at: session.created_at
      }
    end
  end

  def triages_events
    @patient.triages.map do |triage|
      {
        event_type: 'triage',
        id: triage.id,
        details: "#{triage.status} performed by User-#{triage.performed_by_user_id}",
        created_at: triage.created_at
      }
    end
  end

  def vaccination_records_events
    @patient.vaccination_records.map do |vaccination|
      {
        event_type: 'vaccination',
        id: vaccination.id,
        details: "#{vaccination.outcome} at #{Session.find(vaccination.session_id).location.name}",
        created_at: vaccination.created_at
      }
    end
  end

  def class_imports_events
    @patient_events[:class_imports].map do |class_import_id|
      class_import = ClassImport.find(class_import_id)
      {
        event_type: 'patient_class_import',
        id: class_import.id,
        details: "including patient",
        created_at: class_import.created_at
      }
    end
  end

  def cohort_imports_events
    @patient_events[:cohort_imports] do |cohort_import_id|
      cohort_import = CohortImport.find(cohort_import_id)
      {
        event_type: 'patient_cohort_import',
        id: cohort_import.id,
        details: "including patient",
        created_at: cohort_import.created_at
      }
    end
  end

  def org_cohort_imports_events
    @additional_events[:cohort_imports].map do |cohort_import_id|
      cohort_import = CohortImport.find(cohort_import_id)
      {
        event_type: 'patient_cohort_import',
        id: cohort_import.id,
        details: "excluding patient",
        created_at: cohort_import.created_at
      }
    end
  end

  def add_class_imports_events(session_id)
    @additional_events[:class_imports][session_id].map do |class_import_id|
      class_import = ClassImport.find(class_import_id)
      { 
        event_type: 'patient_class_import',
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
    case event[:event_type]
    when 'create'
      "Record created"
    when 'patient_class_import'
      "ClassImport-#{event[:id]} #{event[:details]}"
    when 'patient_cohort_import'
      "CohortImport-#{event[:id]} #{event[:details]}"
    when 'update'
      changes_description = event[:details].map { |key, (before, after)|
        "#{key} from #{before.nil? ? 'nil' : before} to #{after.nil? ? 'nil' : after}" 
      }.join(' ')
      "Updated #{changes_description}"
    when 'school_move'
      "Pending SchoolMove-#{event[:id]} #{event[:details]}"
    when 'school_move_log'
      "SchoolMove-#{event[:id]} #{event[:details]}"
    when 'session'
      "Added to Session-#{event[:id]} #{event[:details]}"
    when 'consent'
      "Consent-#{event[:id]} #{event[:details]}"
    when 'triage'
      "Triage-#{event[:id]} #{event[:details]}"
    when 'vaccination'
      "Vaccination-#{event[:id]} #{event[:details]}"
    when 'destroy'
      "Record destroyed"
    when 'generic'
      "#{event[:details]}-#{event[:id]}"
    else
      "Event-#{event[:id]} #{event[:details]}"
    end
  end
end

class TimelineRecords
  def initialize(patient_id)
    @patient = Patient.find(patient_id)
    @patient_id = patient_id
    @events = []
  end

  def generate_timeline
    load_events
    format_timeline
  end

  private

  def load_events
    @events += @patient.audits.map do |audit|
      {
        event_type: audit.action,
        details: audit.audited_changes,
        created_at: audit.created_at
      }
    end

    @events += @patient.consents.map do |consent|
      {
        event_type: 'consent',
        details: "#{consent.id}, #{consent.response}, via #{consent.route}",
        created_at: consent.created_at
      }
    end

    @events += @patient.school_moves.map do |move|
      {
        event_type: 'school_move',
        details: "#{move.id}, to, #{Location.find(move.school_id).name}, due to, #{move.source}",
        created_at: move.created_at
      }
    end

    @events += @patient.patient_sessions.map do |session|
      {
        event_type: 'session',
        details: "#{session.session_id}, #{Session.find(session.session_id).location.name}",
        created_at: session.created_at
      }
    end

    @events += @patient.triages.map do |triage|
      {
        event_type: 'triage',
        details: "#{triage.id}, #{triage.status}, performed by, User-#{triage.user_id}",
        created_at: triage.created_at
      }
    end

    @events += @patient.vaccination_records.map do |vaccination|
      {
        event_type: 'vaccination',
        details: "#{vaccination.id}, #{vaccination.outcome}, at, #{Session.find(vaccination.session_id).location.name}",
        created_at: vaccination.created_at
      }
    end

    @events += @patient.class_imports.map do |class_import|
      {
        event_type: 'patient_class_import',
        details: "#{class_import.id}, including patient",
        created_at: class_import.created_at
      }
    end

    @events += @patient.cohort_imports.map do |cohort_import|
      {
        event_type: 'patient_cohort_import',
        details: "#{cohort_import.id}, including patient",
        created_at: cohort_import.created_at
      }
    end

    @events.sort_by! { |event| event[:created_at] }
  end

  def format_timeline
    timeline = ["timeline", "title Timeline for Patient-#{@patient_id}"]
    current_date = nil
  
    @events.sort_by! { |event| event[:created_at] }
  
    @events.each do |event|
      event_date = event[:created_at].strftime('%Y-%m-%d')
      event_time = event[:created_at].strftime('%H-%M-%S')
  
      if event_date != current_date
        timeline << "    section #{event_date}"
        current_date = event_date
      end
  
      event_description = case event[:event_type]
                          when 'create'
                            "Created"
                          when 'patient_class_import'
                            "ClassImport-#{event[:details]}"
                          when 'patient_cohort_import'
                            "CohortImport-#{event[:details]}"
                          when 'update'
                            "Updated"
                          when 'destroy'
                            "Destroyed"
                          when 'consent'
                            "Consent-#{event[:details]}"
                          when 'school_move'
                            "Pending SchoolMove-#{event[:details]}"
                          when 'session'
                            "Added to, Session-#{event[:details]}"
                          when 'triage'
                            "Triage-#{event[:details]}"
                          when 'vaccination'
                            "Vaccination-#{event[:details]}"
                          else
                            "Event-#{event[:details]}"
                          end
  
      timeline << "        #{event_time} : #{event_description}"
    end  
    puts timeline.join("\n")
  end   
end

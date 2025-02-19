# frozen_string_literal: true

require_relative "../task_helpers"

namespace :patients do
  desc "Remove parent details for a patient."
  task :remove_parent_details,
       %i[
         patient_id
         parent_email
         parent_phone
         parent_full_name
         ignore_consent
       ] =>
         :environment do |_task, args|
    include TaskHelpers

    if args.to_a.empty? && $stdin.isatty && $stdout.isatty
      patient_id = prompt_user_for "Enter patient id:", required: true
      parent_email = prompt_user_for "Enter parent email (optional):"
      parent_phone = prompt_user_for "Enter parent phone (optional):"
      parent_full_name = prompt_user_for "Enter parent full name (optional):"
      ignore_consent_input = prompt_user_for "Ignore consents? (yes/no):", required: true
      while ignore_consent_input.downcase != "yes" && ignore_consent_input.downcase != "no"
        puts "Invalid input. Please enter 'yes' or 'no'."
        ignore_consent_input = prompt_user_for "Ignore consents? (yes/no):", required: true
      end
      ignore_consent = ignore_consent_input.downcase == "yes"
    elsif args.to_a.size.between?(1, 5)
      patient_id = args[:patient_id]
      parent_email = args[:parent_email]
      parent_phone = args[:parent_phone]
      parent_full_name = args[:parent_full_name]
      ignore_consent = args[:ignore_consent] == "yes"
    else
      raise "Expected 2-5 arguments, got #{args.to_a.size}"
    end

    # Set parent details to nil if not provided
    parent_email = nil if parent_email.blank?
    parent_phone = nil if parent_phone.blank?
    parent_full_name = nil if parent_full_name.blank?

    patient = Patient.find(patient_id)
    if !patient
      puts "Patient not found."
      exit 1
    end
    
    parents = match_parent(patient, parent_email, parent_phone, parent_full_name)
    if parents.count == 0
      puts "Parent not found for patient."
      exit 1
    end
    if parents.count > 1
      puts "Multiple parents found for patient. Please provide more details." 
      exit 1
    end
    parent = parents.first

    # Check for consents attached to the parent or other children
    consents = parent.consents.where(patient: patient)
    other_children = parent.patients.where.not(id: patient.id)

    if consents.any? 
      if !ignore_consent
        puts "Cannot remove parent due to existing consents."
        exit 1
      else
        consents.destroy_all
        puts "Removed consents."
      end
    end

    # Remove relationship between parent and patient
    parent_relationship = ParentRelationship.find_by(parent: parent, patient: patient)
    parent_relationship.destroy if parent_relationship

    if other_children.any?
      puts "Removed relationship between parent and patient."
      exit 1
    else
      # Remove parent
      parent.destroy
      puts "Removed parent and relationship between parent and patient."
      exit 1
    end
  end
end

def match_parent(patient, email, phone, full_name)
  parents = patient.parents
  parents = parents.where(email: email) if email.present?
  parents = parents.where(phone: phone) if phone.present?
  parents = parents.where(full_name: full_name) if full_name.present?
  parents
end

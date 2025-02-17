# frozen_string_literal: true

module FullNameConcern
  extend ActiveSupport::Concern

  included do
    scope :order_by_name,
          -> { order("LOWER(family_name)", "LOWER(given_name)") }
  end

  def full_name(context: :internal)
    FullNameFormatter.call(self, context:)
  end

  def has_preferred_name?
    preferred_given_name.present? || preferred_family_name.present?
  end

  def preferred_full_name(context: :internal)
    FullNameFormatter.call(self, context:, parts_prefix: :preferred)
  end

  def preferred_full_name_changed?
    preferred_given_name_changed? || preferred_family_name_changed?
  end

  def initials
    [given_name[0], family_name[0]].join
  end
end

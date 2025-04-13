# frozen_string_literal: true

module OpsSupportHelper
  def render_ops_support(record)
    partial_name = "ops_support/records/#{record.name.demodulize.underscore}"
    if lookup_context.template_exists?(partial_name, [], true, formats: [:html])
      render partial: partial_name, locals: { record: record }
    else
      render partial: "ops_support/records/default", locals: { record: record }
    end
  end
end

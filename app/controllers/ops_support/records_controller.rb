# frozen_string_literal: true

module OpsSupport
  class RecordsController < ApplicationController
    skip_after_action :verify_policy_scoped
    skip_before_action :authenticate_user!

    layout "full"
    # GET /record_decompositions/:object_type/:id
    def show
      @object_type = safe_get_primary_type
      id = params[:object_id]
      decomposer =
        OpsSupport::RecordDecomposer.new(object_type: @object_type, id: id)
      @decomposed = decomposer.decompose

      filter_association(:patients, params[:q]) if params[:q].present?

      # if @decomposed.blank?
      #   redirect_to root_path, alert: "Record not found" and return
      # end
    end

    def safe_get_primary_type
      params[:object_type].singularize.gsub(/\s+/, '').classify.constantize
    end

    def filter_association(association_name, query)
      assoc = @decomposed[:associations][association_name]
      return unless assoc

      if assoc.respond_to?(:where)
        begin
          # NOTE: This example uses raw SQL condition provided by the user.
          # In production, consider whitelisting or parameterizing allowed conditions.
          @decomposed[:associations][association_name] = assoc.where(query)
        rescue ActiveRecord::StatementInvalid => e
          flash.now[:alert] = "Invalid query: #{e.message}"
          @decomposed[:associations][
            association_name
          ] = assoc.none if assoc.respond_to?(:none)
        end
      end
    end
  end
end

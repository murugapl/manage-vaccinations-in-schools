# frozen_string_literal: true

class ClassImportsController < ApplicationController
  include Pagy::Backend

  before_action :set_session
  before_action :set_class_import, only: %i[show update]

  skip_after_action :verify_policy_scoped, only: %i[new create]

  def new
    @class_import =
      ClassImport.new(organisation: current_user.selected_organisation)
  end

  def create
    @class_import =
      ClassImport.new(
        session: @session,
        organisation: current_user.selected_organisation,
        uploaded_by: current_user,
        **class_import_params
      )

    @class_import.load_data!
    if @class_import.invalid?
      render :new, status: :unprocessable_entity and return
    end

    @class_import.save!

    if @class_import.slow?
      ProcessImportJob.perform_later(@class_import)
      redirect_to imports_path, flash: { success: "Import processing started" }
    else
      ProcessImportJob.perform_now(@class_import)
      redirect_to session_class_import_path(@session, @class_import)
    end
  end

  def show
    @class_import.load_serialized_errors! if @class_import.rows_are_invalid?

    @pagy, @patients = pagy(@class_import.patients.includes(:school))

    @duplicates = @class_import.patients.with_pending_changes.distinct

    render template: "imports/show",
           layout: "full",
           locals: {
             import: @class_import
           }
  end

  def update
    @class_import.process!

    redirect_to session_class_import_path(@session, @class_import)
  end

  private

  def set_session
    @session =
      policy_scope(Session).upcoming.find_by!(slug: params[:session_slug])
  end

  def set_class_import
    @class_import = policy_scope(ClassImport).find(params[:id])
  end

  def class_import_params
    params.fetch(:class_import, {}).permit(:csv)
  end
end

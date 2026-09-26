class Settings::Chancens::MetabaseSettingsComponent < ApplicationComponent
  Field = Data.define(:name, :type, :label, :placeholder, :value, :disabled, :options)
  I18N_SCOPE = "settings.chancens.metabase_settings"

  def env_configured?
    ENV["METABASE_URL"].present? &&
      ENV["METABASE_API_KEY"].present? &&
      ENV["METABASE_STUDENT_QUESTION_ID"].present?
  end

  def fields
    [
      Field.new(
        name: :metabase_url,
        type: :text_field,
        label: t("url_label"),
        placeholder: t("url_placeholder"),
        value: ENV.fetch("METABASE_URL", Setting.metabase_url),
        disabled: ENV["METABASE_URL"].present?,
        options: {
          autocomplete: "off",
          autocapitalize: "none",
          spellcheck: "false",
          inputmode: "url"
        }
      ),
      Field.new(
        name: :metabase_api_key,
        type: :password_field,
        label: t("api_key_label"),
        placeholder: t("api_key_placeholder"),
        value: Setting.metabase_api_key.present? ? "********" : nil,
        disabled: ENV["METABASE_API_KEY"].present?,
        options: {
          autocomplete: "off",
          autocapitalize: "none",
          spellcheck: "false"
        }
      ),
      Field.new(
        name: :metabase_student_question_id,
        type: :text_field,
        label: t("question_id_label"),
        placeholder: t("question_id_placeholder"),
        value: ENV.fetch("METABASE_STUDENT_QUESTION_ID", Setting.metabase_student_question_id),
        disabled: ENV["METABASE_STUDENT_QUESTION_ID"].present?,
        options: {
          autocomplete: "off"
        }
      ),
      Field.new(
        name: :metabase_email_param,
        type: :text_field,
        label: t("email_param_label"),
        placeholder: t("email_param_placeholder"),
        value: ENV.fetch("METABASE_EMAIL_PARAM", Setting.metabase_email_param),
        disabled: ENV["METABASE_EMAIL_PARAM"].present?,
        options: {
          autocomplete: "off",
          autocapitalize: "none"
        }
      )
    ]
  end

  def field_options(field)
    field.options.merge(
      label: field.label,
      placeholder: field.placeholder,
      value: field.value,
      disabled: field.disabled,
      data: { "auto-submit-form-target": "auto" }
    )
  end

  def t(key)
    I18n.t("#{I18N_SCOPE}.#{key}")
  end
end

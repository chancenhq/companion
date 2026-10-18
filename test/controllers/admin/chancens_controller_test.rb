require "test_helper"

class Admin::ChancensControllerTest < ActionDispatch::IntegrationTest
  setup do
    ensure_tailwind_build
    sign_in users(:sure_support_staff)
  end

  test "shows the Metabase settings fields" do
    get admin_chancen_path

    assert_response :success
    assert_includes response.body, 'name="setting[metabase_url]"'
    assert_includes response.body, 'name="setting[metabase_api_key]"'
    assert_includes response.body, 'name="setting[metabase_student_question_id]"'
    assert_includes response.body, 'name="setting[metabase_email_param]"'
  end

  test "updates the submitted Metabase setting" do
    patch admin_chancen_path, params: { setting: { metabase_email_param: "student_email" } }

    assert_redirected_to admin_chancen_path
    assert_equal "student_email", Setting.metabase_email_param
  end

  test "denies non-super-admin users" do
    sign_in users(:family_admin)

    get admin_chancen_path

    assert_redirected_to root_path
  end
end

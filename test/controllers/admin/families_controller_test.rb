require "test_helper"

class Admin::FamiliesControllerTest < ActionDispatch::IntegrationTest
  setup do
    ensure_tailwind_build
    sign_in users(:sure_support_staff)
    @family = families(:empty)
  end

  test "lists families" do
    get admin_families_path

    assert_response :success
    assert_includes response.body, @family.name
  end

  test "edit shows the country select" do
    get edit_admin_family_path(@family)

    assert_response :success
  end

  test "update sets the chancen country code" do
    patch admin_family_path(@family), params: { family: { chancen_country_code: "KE" } }

    assert_redirected_to admin_families_path
    assert_equal "KE", @family.reload.chancen_country_code
  end

  test "non-super-admins are redirected" do
    sign_in users(:family_admin)

    get admin_families_path

    assert_redirected_to root_path
  end
end

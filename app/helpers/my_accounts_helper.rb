module MyAccountsHelper
  # Same store listings the mobile app shares (mobile/lib/screens/settings_screen.dart).
  COMPANION_PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=tech.chancen.companion".freeze
  COMPANION_APP_STORE_URL = "https://apps.apple.com/us/app/chancen-companion/id6794429424".freeze

  def companion_play_store_url
    COMPANION_PLAY_STORE_URL
  end

  def companion_app_store_url
    COMPANION_APP_STORE_URL
  end
end

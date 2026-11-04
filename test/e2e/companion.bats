#!/usr/bin/env bats

COMPOSE=(docker compose -f compose.e2e.yml)
BASE_URL="http://127.0.0.1:13000"
STATE_FILE="${BATS_FILE_TMPDIR}/companion-e2e-state"
ARTIFACT_DIR="${E2E_ARTIFACT_DIR:-tmp/companion-e2e}"

wait_for_app() {
  for _ in $(seq 1 60); do
    if curl -fsS "${BASE_URL}/up" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  return 1
}

setup_file() {
  command -v docker >/dev/null || skip "docker is not installed"
  docker info >/dev/null 2>&1 || skip "docker daemon is not running"
  mkdir -p "${ARTIFACT_DIR}"

  "${COMPOSE[@]}" up -d --build

  wait_for_app

  seed_json=$("${COMPOSE[@]}" exec -T app \
    bundle exec rails runner test/e2e/seed_invitation.rb | tail -n 1)
  [ -n "${seed_json}" ]
  printf '%s\n' "${seed_json}" | jq -e . > "${STATE_FILE}"
}

teardown_file() {
  "${COMPOSE[@]}" logs --no-color > "${ARTIFACT_DIR}/docker-compose.log" 2>&1 || true
  "${COMPOSE[@]}" down --volumes --remove-orphans >/dev/null 2>&1 || true
}

@test "the production image exposes the Rails health endpoint" {
  run curl -fsS "${BASE_URL}/up"
  [ "${status}" -eq 0 ]
}

@test "the public country metadata endpoint exposes live countries" {
  run curl -fsS "${BASE_URL}/api/v1/countries"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *'"code":"KE"'* ]]
  [[ "${output}" == *'"live":true'* ]]
}

@test "an invitation assigns the family country during signup" {
  invitation_token=$(jq -r '.signup_invitation_token' "${STATE_FILE}")
  response=$(curl -sS -w $'\n%{http_code}' \
    -H "Content-Type: application/json" \
    -d "{\"user\":{\"email\":\"companion-e2e-member@example.com\",\"password\":\"SecurePass123!\",\"first_name\":\"E2E\",\"last_name\":\"Member\",\"invitation\":\"${invitation_token}\"},\"device\":{\"device_id\":\"companion-e2e-device\",\"device_name\":\"Bats\",\"device_type\":\"web\",\"os_version\":\"e2e\",\"app_version\":\"e2e\"}}" \
    "${BASE_URL}/api/v1/auth/signup")

  status_code=$(printf '%s\n' "${response}" | tail -n 1)
  body=$(printf '%s\n' "${response}" | sed '$d')
  [ "${status_code}" -eq 201 ]
  [ "$(jq -r '.user.country_code' <<<"${body}")" = "KE" ]
  [ "$(jq -r '.user.email_verified' <<<"${body}")" = "false" ]

  access_token=$(jq -r '.access_token' <<<"${body}")
  run curl -sS -H "Authorization: Bearer ${access_token}" \
    "${BASE_URL}/api/v1/accounts"
  [ "$(jq -r '.error' <<<"${output}")" = "email_verification_required" ]
}

@test "an email confirmation link verifies the user's email" {
  confirmation_token=$(jq -r '.email_confirmation_token' "${STATE_FILE}")
  response=$(curl -sS -w $'\n%{http_code}' \
    "${BASE_URL}/email_confirmation?token=${confirmation_token}")

  status_code=$(printf '%s\n' "${response}" | tail -n 1)
  [ "${status_code}" -eq 200 ]
  verified=$("${COMPOSE[@]}" exec -T app bundle exec rails runner \
    'puts User.find_by!(email: "companion-e2e-verification@example.com").email_verified?')
  [ "${verified}" = "true" ]
}

@test "a password reset token updates the password and is single use" {
  reset_token=$(jq -r '.password_reset_token' "${STATE_FILE}")
  response=$(curl -sS -w $'\n%{http_code}' -X PATCH \
    -H "Content-Type: application/json" \
    -d "{\"token\":\"${reset_token}\",\"password\":\"NewSecurePass123!\",\"password_confirmation\":\"NewSecurePass123!\"}" \
    "${BASE_URL}/api/v1/auth/password_reset")

  status_code=$(printf '%s\n' "${response}" | tail -n 1)
  body=$(printf '%s\n' "${response}" | sed '$d')
  [ "${status_code}" -eq 200 ]
  [ "$(jq -r '.message' <<<"${body}")" = "Password updated. You've been signed out on all devices." ]

  response=$(curl -sS -w $'\n%{http_code}' -X PATCH \
    -H "Content-Type: application/json" \
    -d "{\"token\":\"${reset_token}\",\"password\":\"AnotherPass123!\",\"password_confirmation\":\"AnotherPass123!\"}" \
    "${BASE_URL}/api/v1/auth/password_reset")
  [ "$(printf '%s\n' "${response}" | tail -n 1)" -eq 422 ]
}

@test "an expired invitation cannot be used for signup" {
  expired_token=$(jq -r '.expired_invitation_token' "${STATE_FILE}")
  response=$(curl -sS -w $'\n%{http_code}' \
    -H "Content-Type: application/json" \
    -d "{\"user\":{\"email\":\"companion-e2e-expired@example.com\",\"password\":\"SecurePass123!\",\"first_name\":\"Expired\",\"last_name\":\"Invite\",\"invitation\":\"${expired_token}\"},\"device\":{\"device_id\":\"expired-device\",\"device_name\":\"Bats\",\"device_type\":\"web\",\"os_version\":\"e2e\",\"app_version\":\"e2e\"}}" \
    "${BASE_URL}/api/v1/auth/signup")

  [ "$(printf '%s\n' "${response}" | tail -n 1)" -eq 403 ]
}

@test "an invalid invitation token cannot be used for signup" {
  response=$(curl -sS -w $'\n%{http_code}' \
    -H "Content-Type: application/json" \
    -d '{"user":{"email":"companion-e2e-invalid@example.com","password":"SecurePass123!","first_name":"Invalid","last_name":"Invite","invitation":"not-a-real-token"},"device":{"device_id":"invalid-device","device_name":"Bats","device_type":"web","os_version":"e2e","app_version":"e2e"}}' \
    "${BASE_URL}/api/v1/auth/signup")

  [ "$(printf '%s\n' "${response}" | tail -n 1)" -eq 403 ]
}

@test "the application preserves storage across a container restart" {
  marker="companion-e2e-persisted"
  "${COMPOSE[@]}" exec -T app sh -c "printf '%s' '${marker}' > /rails/storage/e2e-marker"
  "${COMPOSE[@]}" restart app
  wait_for_app

  run "${COMPOSE[@]}" exec -T app cat /rails/storage/e2e-marker
  [ "${status}" -eq 0 ]
  [ "${output}" = "${marker}" ]
}

@test "the application stops without a forced kill" {
  start_time=$(date +%s)
  "${COMPOSE[@]}" stop -t 30 app
  duration=$(( $(date +%s) - start_time ))
  container_id=$("${COMPOSE[@]}" ps -aq app)
  exit_code=$(docker inspect -f '{{.State.ExitCode}}' "${container_id}")

  [ "${duration}" -lt 30 ]
  [ "${exit_code}" -ne 137 ]
}

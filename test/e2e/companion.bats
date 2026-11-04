#!/usr/bin/env bats

COMPOSE=(docker compose -f compose.e2e.yml)
BASE_URL="http://127.0.0.1:13000"
STATE_FILE="${BATS_FILE_TMPDIR}/companion-e2e-state"
ARTIFACT_DIR="${E2E_ARTIFACT_DIR:-tmp/companion-e2e}"

setup_file() {
  command -v docker >/dev/null || skip "docker is not installed"
  docker info >/dev/null 2>&1 || skip "docker daemon is not running"
  mkdir -p "${ARTIFACT_DIR}"

  "${COMPOSE[@]}" up -d --build

  for _ in $(seq 1 60); do
    if curl -fsS "${BASE_URL}/up" >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  curl -fsS "${BASE_URL}/up" >/dev/null

  invitation_token=$("${COMPOSE[@]}" exec -T app \
    bundle exec rails runner test/e2e/seed_invitation.rb | tail -n 1)
  [ -n "${invitation_token}" ]
  printf '%s\n' "${invitation_token}" > "${STATE_FILE}"
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
  invitation_token=$(<"${STATE_FILE}")
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

@test "the application stops without a forced kill" {
  start_time=$(date +%s)
  "${COMPOSE[@]}" stop -t 30 app
  duration=$(( $(date +%s) - start_time ))
  container_id=$("${COMPOSE[@]}" ps -aq app)
  exit_code=$(docker inspect -f '{{.State.ExitCode}}' "${container_id}")

  [ "${duration}" -lt 30 ]
  [ "${exit_code}" -ne 137 ]
}

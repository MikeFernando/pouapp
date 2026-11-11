#!/usr/bin/env bash
# IPA produção — bundle com.pouapp.app | API Railway
# App Store Connect: PouApp (TestFlight only com --upload-testflight — sem review/publicação).
#
# Uso:
#   ./scripts/release_ios_prod.sh
#   ./scripts/release_ios_prod.sh --upload-testflight
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/ios_asc.sh"

DEFINES="${ROOT}/dart_defines/prod.json"
IPA_DIR="${ROOT}/build/ios/ipa"
ARTIFACTS="${ROOT}/artifacts"
PUBSPEC="${ROOT}/pubspec.yaml"
EXPORT_OPTIONS="${ROOT}/ios/ExportOptions.plist"
EXPECT_BUNDLE_ID="com.pouapp.app"
EXPECT_DISPLAY_NAME="PouApp"
EXPECT_ASC_APP_NAME="PouApp"
EXPECT_API_HOST="pouapp-api-production.up.railway.app"

UPLOAD_TESTFLIGHT=false
for arg in "$@"; do
  case "$arg" in
    --upload-testflight) UPLOAD_TESTFLIGHT=true ;;
    -h|--help)
      printf 'Uso: %s [--upload-testflight]\n' "$0"
      exit 0
      ;;
    *)
      printf 'Opção desconhecida: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

log() { printf '==> %s\n' "$*"; }
die() { printf 'Erro: %s\n' "$*" >&2; exit 1; }

[[ -f "$DEFINES" ]] || die "Falta $DEFINES"
[[ -f "$PUBSPEC" ]] || die "Falta $PUBSPEC"
[[ -f "$EXPORT_OPTIONS" ]] || die "Falta $EXPORT_OPTIONS"
command -v flutter >/dev/null || die "flutter não encontrado no PATH"
command -v python3 >/dev/null || die "python3 é necessário"

ios_asc_load_env "$ROOT" || die "falha ao carregar App Store Connect API"
ios_asc_ensure_store_profile "$EXPECT_BUNDLE_ID" "" \
  || die "provisioning App Store ausente para $EXPECT_BUNDLE_ID"

python3 - "$DEFINES" "$EXPECT_API_HOST" <<'PY' || die "defines inválidos"
import json, sys
d = json.load(open(sys.argv[1]))
host = sys.argv[2]
api = d.get("API_BASE_URL", "")
assert host in api, api
assert "127.0.0.1" not in api
assert "localhost" not in api
print("defines OK")
PY

version_line="$(grep -E '^version:[[:space:]]*[0-9]' "$PUBSPEC" | head -1)"
version="${version_line#version:}"
version="${version// /}"
[[ "$version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]] || die "version inválida: $version"
version_name="${BASH_REMATCH[1]}"
version_code="${BASH_REMATCH[2]}"

cd "$ROOT"
log "API=${EXPECT_API_HOST}"
log "Bundle=${EXPECT_BUNDLE_ID} | Display=${EXPECT_DISPLAY_NAME} | v${version_name}+${version_code}"

flutter pub get
rm -f "$IPA_DIR"/*.ipa
flutter build ipa \
  --release \
  --dart-define-from-file="$DEFINES" \
  --export-options-plist="$EXPORT_OPTIONS"

shopt -s nullglob
ipas=("$IPA_DIR"/*.ipa)
[[ ${#ipas[@]} -gt 0 ]] || die "IPA não encontrado em $IPA_DIR"
IPA="${ipas[0]}"
[[ -s "$IPA" ]] || die "IPA vazio"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q -o "$IPA" -d "$TMP"
APP="$(find "$TMP/Payload" -name '*.app' -type d | head -1)"
[[ -n "$APP" ]] || die "Runner.app ausente no IPA"
APP_INFO="$APP/Info.plist"

python3 - "$APP_INFO" \
  "$EXPECT_BUNDLE_ID" "$EXPECT_DISPLAY_NAME" \
  "$version_name" "$version_code" <<'PY' || die "IPA inválido"
import plistlib, sys
info = plistlib.load(open(sys.argv[1], "rb"))
bundle, display, ver, build = sys.argv[2:6]
assert info.get("CFBundleIdentifier") == bundle, info.get("CFBundleIdentifier")
assert info.get("CFBundleDisplayName") == display, info.get("CFBundleDisplayName")
assert str(info.get("CFBundleShortVersionString")) == ver, info.get("CFBundleShortVersionString")
assert str(info.get("CFBundleVersion")) == build, info.get("CFBundleVersion")
print("IPA Bundle/Display/Version OK")
PY

ios_validate_distribution_signature "$IPA" || die "assinatura Distribution inválida"

mkdir -p "$ARTIFACTS"
OUT="${ARTIFACTS}/pouapp-production-v${version_name}+${version_code}.ipa"
cp -f "$IPA" "$OUT"
BASE="pouapp-production-v${version_name}+${version_code}"
find "$ARTIFACTS" -maxdepth 1 -type f -name 'pouapp-production-*.ipa' \
  ! -name "${BASE}.ipa" -delete

log "IPA produção: $OUT"
log "bundle=$EXPECT_BUNDLE_ID display=$EXPECT_DISPLAY_NAME"

if [[ "$UPLOAD_TESTFLIGHT" == true ]]; then
  log "Upload TestFlight → ${EXPECT_ASC_APP_NAME} (${EXPECT_BUNDLE_ID})"
  # App Store Connect API Key não consegue CREATE de apps — o registro precisa existir na ASC.
  python3 - "$EXPECT_BUNDLE_ID" "$EXPECT_ASC_APP_NAME" \
    "$APP_STORE_API_KEY" "$APP_STORE_ISSUER_ID" "$APP_STORE_KEY_PATH" <<'PY' || die "app ASC ausente"
import base64, json, pathlib, subprocess, sys, time
from urllib.request import Request, urlopen
from urllib.error import HTTPError
bundle, name, key_id, issuer, key_path = sys.argv[1:6]
def b64url(d): return base64.urlsafe_b64encode(d).rstrip(b"=").decode()
now = int(time.time())
header = b64url(json.dumps({"alg":"ES256","kid":key_id,"typ":"JWT"}).encode())
payload = b64url(json.dumps({"iss":issuer,"iat":now,"exp":now+1200,"aud":"appstoreconnect-v1"}).encode())
msg = f"{header}.{payload}".encode()
script = ("const fs=require('fs');const crypto=require('crypto');"
          f"const priv=fs.readFileSync({json.dumps(key_path)});"
          f"const m=Buffer.from({json.dumps(msg.decode())});"
          "process.stdout.write(crypto.sign('sha256', m, {key:priv, dsaEncoding:'ieee-p1363'}));")
sig = b64url(subprocess.check_output(["node", "-e", script]))
token = f"{header}.{payload}.{sig}"
req = Request("https://api.appstoreconnect.apple.com/v1/apps?limit=100",
              headers={"Authorization": f"Bearer {token}"})
try:
    apps = json.load(urlopen(req)).get("data") or []
except HTTPError as e:
    print(e.read().decode(), file=sys.stderr); raise SystemExit(1)
exact = [a for a in apps if (a.get("attributes") or {}).get("bundleId") == bundle]
if name:
    named = [a for a in exact if (a.get("attributes") or {}).get("name") == name]
    if named:
        exact = named
if not exact:
    print(
        f"Erro: app '{name}' ({bundle}) não existe no App Store Connect.\n"
        f"Crie em Apps → + → New App:\n"
        f"  Platforms: iOS\n"
        f"  Name: {name}\n"
        f"  Primary Language: Portuguese (Brazil)\n"
        f"  Bundle ID: {bundle}\n"
        f"  SKU: pouapp-ios\n"
        f"Depois rode de novo: ./scripts/release_ios_prod.sh --upload-testflight",
        file=sys.stderr,
    )
    raise SystemExit(1)
print(f"ASC app OK: {exact[0]['attributes'].get('name')} ({bundle})")
PY
  ios_asc_upload_ipa "$OUT" || die "upload TestFlight falhou"
  ios_asc_confirm_build "$EXPECT_BUNDLE_ID" "$version_name" "$version_code" "$EXPECT_ASC_APP_NAME" \
    || die "confirmação ASC falhou"
  log "Upload concluído — apenas TestFlight (sem review / sem publicação)."
fi

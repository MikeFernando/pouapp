#!/usr/bin/env bash
# Biblioteca compartilhada: ASC auth, provisioning, upload TestFlight.
# shellcheck shell=bash

ios_asc_load_env() {
  local root="${1:?}"
  local candidates=(
    "${root}/scripts/ios_appstore.env"
    "${HOME}/nileon-admin/nileon_admin/scripts/ios_appstore.env"
    "/Users/mikefernandodasilva/nileon-admin/nileon_admin/scripts/ios_appstore.env"
  )
  local envf
  for envf in "${candidates[@]}"; do
    if [[ -f "$envf" ]]; then
      # shellcheck disable=SC1090
      source "$envf"
      break
    fi
  done

  APP_STORE_API_KEY="${APP_STORE_API_KEY:-33PJV462MA}"

  local key_path="${APP_STORE_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${APP_STORE_API_KEY}.p8}"
  key_path="${key_path/#\~/$HOME}"
  # Expand $HOME if literal in env file
  key_path="${key_path//\$HOME/$HOME}"

  if [[ ! -f "$key_path" ]]; then
    echo "Erro: chave API não encontrada: $key_path" >&2
    echo "Coloque AuthKey_${APP_STORE_API_KEY}.p8 em ~/.appstoreconnect/private_keys/ (chmod 600)." >&2
    return 1
  fi
  chmod 600 "$key_path" 2>/dev/null || true

  if [[ -z "${APP_STORE_ISSUER_ID:-}" || "${APP_STORE_ISSUER_ID}" == xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx ]]; then
    echo "Erro: APP_STORE_ISSUER_ID não configurado em scripts/ios_appstore.env" >&2
    return 1
  fi

  export APP_STORE_API_KEY APP_STORE_ISSUER_ID
  export APP_STORE_KEY_PATH="$key_path"
  ASC_XCODE_AUTH=(
    -allowProvisioningUpdates
    -authenticationKeyPath "$APP_STORE_KEY_PATH"
    -authenticationKeyID "$APP_STORE_API_KEY"
    -authenticationKeyIssuerID "$APP_STORE_ISSUER_ID"
  )
}

# Garante profile App Store local para um Bundle ID (reutiliza ou baixa da ASC).
# Args: bundle_id [expected_profile_name]
ios_asc_ensure_store_profile() {
  local bundle_id="${1:?}"
  local expect_name="${2:-}"
  python3 - "$bundle_id" "$expect_name" "$APP_STORE_API_KEY" "$APP_STORE_ISSUER_ID" "$APP_STORE_KEY_PATH" <<'PY'
import base64, json, os, plistlib, subprocess, sys, tempfile, pathlib, time, hashlib, hmac, struct
from urllib.request import Request, urlopen
from urllib.error import HTTPError

bundle_id, expect_name, key_id, issuer, key_path = sys.argv[1:6]

def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

def es256_sign(message: bytes, pem: bytes) -> bytes:
    # Use openssl for ES256 ieee-p1363
    with tempfile.NamedTemporaryFile() as msgf, tempfile.NamedTemporaryFile() as sigf, tempfile.NamedTemporaryFile() as keyf:
        msgf.write(message); msgf.flush()
        keyf.write(pem); keyf.flush()
        # DER signature then convert — use python cryptography if available, else openssl dgst + manual
        try:
            from cryptography.hazmat.primitives import hashes, serialization
            from cryptography.hazmat.primitives.asymmetric import ec
            key = serialization.load_pem_private_key(pem, password=None)
            der = key.sign(message, ec.ECDSA(hashes.SHA256()))
            # Convert DER ECDSA to raw r||s (64 bytes for P-256)
            from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
            r, s = decode_dss_signature(der)
            return r.to_bytes(32, "big") + s.to_bytes(32, "big")
        except ImportError:
            pass
        # Fallback: node is available on this machine
        import subprocess as sp
        script = f"""
const fs=require('fs');const crypto=require('crypto');
const priv=fs.readFileSync({json.dumps(key_path)});
const msg=Buffer.from({json.dumps(message.decode())});
const sig=crypto.sign('sha256', msg, {{key:priv, dsaEncoding:'ieee-p1363'}});
process.stdout.write(sig);
"""
        return sp.check_output(["node", "-e", script])

pem = pathlib.Path(key_path).read_bytes()
now = int(time.time())
header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
payload = b64url(json.dumps({"iss": issuer, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}).encode())
signing_input = f"{header}.{payload}".encode()
sig = b64url(es256_sign(signing_input, pem))
token = f"{header}.{payload}.{sig}"

def api(method, path, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = Request(
        f"https://api.appstoreconnect.apple.com{path}",
        data=data,
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urlopen(req) as r:
            return r.status, json.load(r)
    except HTTPError as e:
        return e.code, json.load(e)

def install_profile_bytes(content_b64: str, name: str):
    raw = base64.b64decode(content_b64)
    with tempfile.NamedTemporaryFile(suffix=".mobileprovision", delete=False) as tf:
        tf.write(raw)
        tmp = tf.name
    meta = subprocess.check_output(["security", "cms", "-D", "-i", tmp])
    info = plistlib.loads(meta)
    uuid = info["UUID"]
    app = info["Entitlements"]["application-identifier"]
    assert app == bundle_id or app.endswith("." + bundle_id), (bundle_id, app)
    if expect_name and info.get("Name") != expect_name:
        print(f"aviso: nome do profile '{info.get('Name')}' != '{expect_name}'", file=sys.stderr)
    homes = [
        pathlib.Path.home() / "Library/MobileDevice/Provisioning Profiles",
        pathlib.Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles",
    ]
    for d in homes:
        d.mkdir(parents=True, exist_ok=True)
        dest = d / f"{uuid}.mobileprovision"
        dest.write_bytes(raw)
        print(f"profile instalado: {dest.name} ({info.get('Name')})")
    os.unlink(tmp)

# 1) Local scan
found_local = False
search_dirs = [
    pathlib.Path.home() / "Library/MobileDevice/Provisioning Profiles",
    pathlib.Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles",
]
for d in search_dirs:
    if not d.is_dir():
        continue
    for f in d.glob("*.mobileprovision"):
        try:
            meta = subprocess.check_output(["security", "cms", "-D", "-i", str(f)], stderr=subprocess.DEVNULL)
            info = plistlib.loads(meta)
        except Exception:
            continue
        app = info.get("Entitlements", {}).get("application-identifier", "")
        # App Store profiles typically lack get-task-allow and have ProvisionsAllDevices or no ProvisionedDevices
        name = info.get("Name", "")
        # Match the bundle exactly. `in` also hits NotificationService
        # (com.nileon.app.staging is a prefix of com.nileon.app.staging.NotificationService).
        if (app == bundle_id or app.endswith("." + bundle_id)) and (
            (expect_name and name == expect_name)
            or ("App Store" in name or "Store" in name)
            or info.get("ProvisionsAllDevices") is True
            or ("ProvisionedDevices" not in info and "Developer" not in name)
        ):
            # Prefer non-development
            if info.get("Entitlements", {}).get("get-task-allow"):
                continue
            print(f"profile local OK: {name} ({f.name})")
            found_local = True
            break
    if found_local:
        break

if found_local:
    sys.exit(0)

print(f"profile local ausente para {bundle_id}; consultando App Store Connect…")
st, data = api("GET", f"/v1/bundleIds?filter[identifier]={bundle_id}&limit=5")
if st >= 400 or not data.get("data"):
    print(f"Erro: Bundle ID {bundle_id} não encontrado na ASC ({st})", file=sys.stderr)
    sys.exit(1)
exact = [
    b for b in data["data"]
    if (b.get("attributes") or {}).get("identifier") == bundle_id
]
if not exact:
    print(f"Erro: Bundle ID {bundle_id} não encontrado na ASC (filtro impreciso)", file=sys.stderr)
    sys.exit(1)
bid = exact[0]["id"]
st, data = api("GET", f"/v1/bundleIds/{bid}/profiles?limit=50")
profiles = data.get("data") or []
store = [
    p for p in profiles
    if p["attributes"].get("profileType") == "IOS_APP_STORE"
    and p["attributes"].get("profileState") == "ACTIVE"
]
if expect_name:
    named = [p for p in store if p["attributes"].get("name") == expect_name]
    if named:
        store = named
if not store:
    print(
        f"Erro: nenhum profile IOS_APP_STORE ACTIVE para {bundle_id}. "
        f"Crie '{expect_name or 'App Store'}' no Apple Developer.",
        file=sys.stderr,
    )
    sys.exit(1)

prof = store[0]
st, detail = api("GET", f"/v1/profiles/{prof['id']}")
content = detail["data"]["attributes"]["profileContent"]
install_profile_bytes(content, prof["attributes"]["name"])
print(f"profile baixado da ASC: {prof['attributes']['name']}")
PY
}

ios_asc_upload_ipa() {
  local ipa="${1:?}"
  [[ -f "$ipa" ]] || { echo "Erro: IPA não encontrado: $ipa" >&2; return 1; }
  echo "==> Upload TestFlight"
  echo "==> IPA: $ipa"
  echo "==> API Key: $APP_STORE_API_KEY"

  local transporter=""
  if [[ -x "/Applications/Transporter.app/Contents/itms/bin/iTMSTransporter" ]]; then
    transporter="/Applications/Transporter.app/Contents/itms/bin/iTMSTransporter"
  elif [[ -x "$HOME/Applications/Transporter.app/Contents/itms/bin/iTMSTransporter" ]]; then
    transporter="$HOME/Applications/Transporter.app/Contents/itms/bin/iTMSTransporter"
  fi

  if [[ -n "$transporter" ]]; then
    echo "==> via iTMSTransporter ($transporter)"
    "$transporter" -m upload \
      -assetFile "$ipa" \
      -apiKey "$APP_STORE_API_KEY" \
      -apiIssuer "$APP_STORE_ISSUER_ID" \
      -v informational
    return $?
  fi

  # Xcode 15+ stub de `xcrun iTMSTransporter` pede o app Transporter da Mac App Store.
  # Fallback estável: altool (ContentDelivery) com a mesma API Key.
  echo "==> via altool (Transporter.app não instalado)"
  xcrun altool --upload-app --type ios \
    -f "$ipa" \
    --apiKey "$APP_STORE_API_KEY" \
    --apiIssuer "$APP_STORE_ISSUER_ID"
}

# Confirma que o app ASC com o Bundle ID tem um build recente (versão/build).
# Args: bundle_id version_name version_code [expected_app_name]
ios_asc_confirm_build() {
  local bundle_id="${1:?}"
  local version_name="${2:?}"
  local version_code="${3:?}"
  local expect_app_name="${4:-}"
  python3 - "$bundle_id" "$version_name" "$version_code" "$expect_app_name" \
    "$APP_STORE_API_KEY" "$APP_STORE_ISSUER_ID" "$APP_STORE_KEY_PATH" <<'PY'
import base64, json, pathlib, sys, time, tempfile, subprocess
from urllib.request import Request, urlopen
from urllib.error import HTTPError

bundle_id, ver, build, expect_name, key_id, issuer, key_path = sys.argv[1:8]

def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

def make_token():
    pem = pathlib.Path(key_path).read_bytes()
    now = int(time.time())
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    payload = b64url(json.dumps({"iss": issuer, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}).encode())
    msg = f"{header}.{payload}".encode()
    try:
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import ec
        from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
        key = serialization.load_pem_private_key(pem, password=None)
        der = key.sign(msg, ec.ECDSA(hashes.SHA256()))
        r, s = decode_dss_signature(der)
        sig = b64url(r.to_bytes(32, "big") + s.to_bytes(32, "big"))
    except ImportError:
        import json as _json
        script = (
            "const fs=require('fs');const crypto=require('crypto');"
            f"const priv=fs.readFileSync({_json.dumps(key_path)});"
            f"const msg=Buffer.from({_json.dumps(msg.decode())});"
            "const sig=crypto.sign('sha256', msg, {key:priv, dsaEncoding:'ieee-p1363'});"
            "process.stdout.write(Buffer.from(sig).toString('base64url'));"
        )
        sig = subprocess.check_output(["node", "-e", script]).decode()
    return f"{header}.{payload}.{sig}"

token = make_token()

def api(path):
    req = Request(
        f"https://api.appstoreconnect.apple.com{path}",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urlopen(req) as r:
        return json.load(r)

# filter[bundleId] is prefix-ish — prefer exact bundleId match.
apps = api(f"/v1/apps?filter[bundleId]={bundle_id}&limit=20").get("data") or []
exact = [a for a in apps if a.get("attributes", {}).get("bundleId") == bundle_id]
if expect_name:
    named = [a for a in exact if a.get("attributes", {}).get("name") == expect_name]
    if named:
        exact = named
if not exact:
    print(f"Erro: app ASC não encontrado para bundleId exato {bundle_id}", file=sys.stderr)
    for a in apps:
        print(
            f"  candidato: name={a.get('attributes', {}).get('name')!r} "
            f"bundleId={a.get('attributes', {}).get('bundleId')!r}",
            file=sys.stderr,
        )
    sys.exit(1)
app = exact[0]
name = app["attributes"].get("name")
print(f"ASC app: {name} ({bundle_id})")
if expect_name and name != expect_name:
    print(f"Erro: app ASC '{name}' != esperado '{expect_name}'", file=sys.stderr)
    sys.exit(1)

app_id = app["id"]
# Poll a few times — processing can lag
deadline = time.time() + 180
found = None
while time.time() < deadline:
    builds = api(
        f"/v1/builds?filter[app]={app_id}&filter[version]={build}&limit=10&sort=-uploadedDate"
    ).get("data") or []
    for b in builds:
        # version filter is CFBundleVersion; also check preReleaseVersion via include if needed
        attrs = b.get("attributes") or {}
        print(f"  build candidate id={b['id']} version={attrs.get('version')} processing={attrs.get('processingState')}")
        found = b
        break
    if found:
        break
    print("aguardando build aparecer no ASC…")
    time.sleep(15)

if not found:
    print(
        f"aviso: upload concluído, mas build {ver} ({build}) ainda não listado no ASC "
        f"(processamento pode levar alguns minutos). App confirmado: {name}",
        file=sys.stderr,
    )
    sys.exit(0)

print(f"OK: build presente em '{name}' — processingState={found['attributes'].get('processingState')}")
PY
}

ios_validate_distribution_signature() {
  local app_or_ipa="${1:?}"
  python3 - "$app_or_ipa" <<'PY' || exit 1
import plistlib, subprocess, sys, tempfile, zipfile, shutil
from pathlib import Path

target = Path(sys.argv[1])
tmpdir = None
app = None
try:
    if target.suffix == ".ipa":
        tmpdir = Path(tempfile.mkdtemp())
        with zipfile.ZipFile(target) as z:
            z.extractall(tmpdir)
        apps = list((tmpdir / "Payload").glob("*.app"))
        assert apps, "Runner.app ausente no IPA"
        app = apps[0]
    else:
        app = target

    out = subprocess.check_output(["codesign", "-dv", "--verbose=4", str(app)], stderr=subprocess.STDOUT).decode()
    print(out)
    if "Authority=Apple Distribution:" not in out and "Authority=Apple Distribution" not in out:
        # also accept "Authority=Apple Distribution: Mike Silva ..."
        if "Apple Distribution" not in out:
            raise SystemExit("Assinatura não é Apple Distribution")
    if "Authority=Apple Development:" in out and "Apple Distribution" not in out:
        raise SystemExit("IPA ainda assinado com Apple Development")
    print("assinatura Apple Distribution OK")
finally:
    if tmpdir:
        shutil.rmtree(tmpdir, ignore_errors=True)
PY
}

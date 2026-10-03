#!/usr/bin/env bash
# Prepare an installable Direct APK signing identity for continuous main builds.
# Prefer externally supplied GB_ANDROID_DIRECT_* inputs. Otherwise create or reuse
# a stable continuous keystore under $BUILD_DIR so CI can publish a signed APK
# without shipping an unsigned package that Android refuses to install.
set -euo pipefail

if [[ -n "${GB_ANDROID_DIRECT_KEYSTORE:-}" &&
      -n "${GB_ANDROID_DIRECT_KEYSTORE_PASSWORD:-}" &&
      -n "${GB_ANDROID_DIRECT_KEY_ALIAS:-}" &&
      -n "${GB_ANDROID_DIRECT_KEY_PASSWORD:-}" ]]; then
  echo "Using externally supplied Android Direct signing inputs."
  exit 0
fi

if [[ -z "${BUILD_DIR:-}" ]]; then
  echo "BUILD_DIR is required." >&2
  exit 1
fi

dir="$BUILD_DIR/continuous-android-signing"
keystore="$dir/continuous.jks"
password='galaxybridge-continuous'
alias='galaxybridge-continuous'

mkdir -p "$dir"
if [[ ! -f "$keystore" ]]; then
  keytool -genkeypair \
    -v \
    -keystore "$keystore" \
    -storepass "$password" \
    -keypass "$password" \
    -alias "$alias" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname 'CN=Galaxy Bridge Continuous, OU=CI, O=GalaxyBridge, L=Internet, ST=NA, C=US'
fi

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "GB_ANDROID_DIRECT_KEYSTORE=$keystore"
    echo "GB_ANDROID_DIRECT_KEYSTORE_PASSWORD=$password"
    echo "GB_ANDROID_DIRECT_KEY_ALIAS=$alias"
    echo "GB_ANDROID_DIRECT_KEY_PASSWORD=$password"
  } >> "$GITHUB_ENV"
fi

export GB_ANDROID_DIRECT_KEYSTORE="$keystore"
export GB_ANDROID_DIRECT_KEYSTORE_PASSWORD="$password"
export GB_ANDROID_DIRECT_KEY_ALIAS="$alias"
export GB_ANDROID_DIRECT_KEY_PASSWORD="$password"
echo "Prepared continuous Android signing identity at $keystore"

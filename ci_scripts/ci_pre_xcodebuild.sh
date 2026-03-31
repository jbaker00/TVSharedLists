#!/bin/sh
# Xcode Cloud pre-build script
# Generates GoogleService-Info.plist and patches the Google Sign-In URL scheme
# from environment variables set in the Xcode Cloud workflow.
#
# Required secrets (Xcode Cloud → Workflow → Environment → Secrets):
#   FIREBASE_API_KEY
#   FIREBASE_GCM_SENDER_ID
#   FIREBASE_PROJECT_ID
#   FIREBASE_STORAGE_BUCKET
#   FIREBASE_GOOGLE_APP_ID
#   FIREBASE_BUNDLE_ID
#   FIREBASE_CLIENT_ID          ← iOS OAuth client ID (from Firebase Console after enabling Google Sign-In)
#   FIREBASE_REVERSED_CLIENT_ID ← Reverse of CLIENT_ID (used as URL scheme)

set -e

PLIST_PATH="$CI_WORKSPACE/TVSharedLists/GoogleService-Info.plist"
INFO_PLIST="$CI_WORKSPACE/TVSharedLists/Info.plist"

# ── Validate required variables ────────────────────────────────────────────
MISSING=""
for VAR in FIREBASE_API_KEY FIREBASE_GCM_SENDER_ID FIREBASE_PROJECT_ID \
           FIREBASE_STORAGE_BUCKET FIREBASE_GOOGLE_APP_ID FIREBASE_BUNDLE_ID \
           FIREBASE_CLIENT_ID FIREBASE_REVERSED_CLIENT_ID; do
    eval VALUE=\$$VAR
    if [ -z "$VALUE" ]; then
        MISSING="$MISSING $VAR"
    fi
done

if [ -n "$MISSING" ]; then
    echo "ERROR: Missing required environment variables:$MISSING"
    echo "Set them in Xcode Cloud → Workflow → Environment → Secrets."
    exit 1
fi

# ── Write GoogleService-Info.plist ─────────────────────────────────────────
cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>${FIREBASE_API_KEY}</string>
	<key>GCM_SENDER_ID</key>
	<string>${FIREBASE_GCM_SENDER_ID}</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>${FIREBASE_BUNDLE_ID}</string>
	<key>PROJECT_ID</key>
	<string>${FIREBASE_PROJECT_ID}</string>
	<key>STORAGE_BUCKET</key>
	<string>${FIREBASE_STORAGE_BUCKET}</string>
	<key>CLIENT_ID</key>
	<string>${FIREBASE_CLIENT_ID}</string>
	<key>REVERSED_CLIENT_ID</key>
	<string>${FIREBASE_REVERSED_CLIENT_ID}</string>
	<key>IS_ADS_ENABLED</key>
	<false/>
	<key>IS_ANALYTICS_ENABLED</key>
	<false/>
	<key>IS_APPINVITE_ENABLED</key>
	<true/>
	<key>IS_GCM_ENABLED</key>
	<true/>
	<key>IS_SIGNIN_ENABLED</key>
	<true/>
	<key>GOOGLE_APP_ID</key>
	<string>${FIREBASE_GOOGLE_APP_ID}</string>
</dict>
</plist>
PLIST

echo "GoogleService-Info.plist written."

# ── Patch the Google Sign-In URL scheme in Info.plist ──────────────────────
# The scheme entry already exists (set to $(REVERSED_CLIENT_ID) in source).
# PlistBuddy writes the real value so the build setting substitution isn't needed.
/usr/libexec/PlistBuddy \
    -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 ${FIREBASE_REVERSED_CLIENT_ID}" \
    "$INFO_PLIST"

echo "Info.plist URL scheme patched to ${FIREBASE_REVERSED_CLIENT_ID}"

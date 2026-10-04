#!/usr/bin/env python3
import plistlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    raise SystemExit(message)


def load(path: str):
    with (ROOT / path).open("rb") as handle:
        return plistlib.load(handle)


project = (ROOT / "LiDARForge.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
info = load("LiDARForge/Info.plist")
privacy = load("LiDARForge/PrivacyInfo.xcprivacy")

versions = set(re.findall(r"MARKETING_VERSION = ([0-9.]+);", project))
builds = set(re.findall(r"CURRENT_PROJECT_VERSION = ([0-9]+);", project))
if len(versions) != 1 or len(builds) != 1:
    fail(f"version contract failed: versions={sorted(versions)} builds={sorted(builds)}")

version = next(iter(versions))
build = next(iter(builds))

if info.get("ITSAppUsesNonExemptEncryption") is not False:
    fail("export compliance contract failed: app must declare no non-exempt encryption unless behavior changes")

for key in ["NSCameraUsageDescription", "NSMotionUsageDescription"]:
    if not str(info.get(key, "")).strip():
        fail(f"permission contract failed: {key} is missing")

if privacy.get("NSPrivacyTracking") is not False:
    fail("privacy contract failed: tracking must be false")

reasons = {
    item.get("NSPrivacyAccessedAPIType"): set(item.get("NSPrivacyAccessedAPITypeReasons", []))
    for item in privacy.get("NSPrivacyAccessedAPITypes", [])
}
if "CA92.1" not in reasons.get("NSPrivacyAccessedAPICategoryUserDefaults", set()):
    fail("privacy contract failed: UserDefaults required-reason CA92.1 is missing")

for token in [
    "PrivacyInfo.xcprivacy in Resources",
    "InfoPlist.strings in Resources",
]:
    if token not in project:
        fail(f"Xcode resource contract failed: missing {token}")

for locale in ["en", "es"]:
    strings = (
        ROOT / f"LiDARForge/Resources/{locale}.lproj/InfoPlist.strings"
    ).read_text(encoding="utf-8")
    for key in ["NSCameraUsageDescription", "NSMotionUsageDescription"]:
        if f'"{key}"' not in strings:
            fail(f"permission localization failed: {locale} missing {key}")

hardcoded_teams = [
    value.strip().strip('"')
    for value in re.findall(r"DEVELOPMENT_TEAM = ([^;]*);", project)
    if value.strip().strip('"')
]
if hardcoded_teams:
    fail(f"signing contract failed: hardcoded Apple team(s): {hardcoded_teams}")

settings = (ROOT / "LiDARForge/Views/SettingsView.swift").read_text(encoding="utf-8")
if 'LabeledContent("settings.version", value: "0.2.0")' in settings:
    fail("version UI contract failed: Settings must read CFBundleShortVersionString")

workflow = (ROOT / ".github/workflows/ios-build.yml").read_text(encoding="utf-8")
for token in [
    "Build Release for iOS Simulator",
    "Build Release for iPhoneOS",
    "Static Analyze Release",
    "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES",
]:
    if token not in workflow:
        fail(f"CI contract failed: missing {token}")

testflight = ROOT / "docs/TESTFLIGHT.md"
if not testflight.exists():
    fail("release contract failed: docs/TESTFLIGHT.md is missing")

if not (ROOT / "LICENSE").exists():
    fail("repository contract failed: LICENSE is missing")

print(
    f"PASS: LiDARForge {version} (build {build}) release resources, privacy, "
    "localized permissions, signing hygiene and TestFlight CI contract"
)

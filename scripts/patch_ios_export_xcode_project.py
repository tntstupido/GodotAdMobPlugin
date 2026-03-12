#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path
import sys


BUILD_FILE_SWIFT = '\t\t1FF8DBB31FBA9DE1009DE661 /* dummy.swift in Sources */ = {isa = PBXBuildFile; fileRef = 1FF8DBB21FBA9DE1009DE661 /* dummy.swift */; };\n'
FILE_REF_SWIFT = '\t\t1FF8DBB21FBA9DE1009DE661 /* dummy.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = dummy.swift; sourceTree = "<group>"; };\n'

JSC_BUILD = '589384010000000000000010 = {isa = PBXBuildFile; fileRef = 589384010000000000000011; };\n'
JSC_REF = '589384010000000000000011 = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = "JavaScriptCore.framework"; path = "/System/Library/Frameworks/JavaScriptCore.framework"; sourceTree = "<group>"; };\n'


def insert_once(text: str, needle: str, payload: str, *, after: bool = True) -> str:
    if payload.strip() in text:
        return text
    idx = text.find(needle)
    if idx == -1:
        raise RuntimeError(f"Needle not found: {needle!r}")
    insert_at = idx + len(needle) if after else idx
    return text[:insert_at] + payload + text[insert_at:]


def replace_once(text: str, needle: str, replacement: str) -> str:
    if needle not in text:
        return text
    return text.replace(needle, replacement, 1)


def collapse_duplicates(text: str, line: str) -> str:
    doubled = line + line
    while doubled in text:
        text = text.replace(doubled, line)
    return text


def patch_pbxproj(pbxproj_path: Path) -> bool:
    original = pbxproj_path.read_text()
    text = original

    text = insert_once(
        text,
        '\t\t1FF8DBB11FBA9DE1009DE660 /* dummy.cpp in Sources */ = {isa = PBXBuildFile; fileRef = 1FF8DBB01FBA9DE1009DE660 /* dummy.cpp */; };\n',
        BUILD_FILE_SWIFT,
    )
    text = insert_once(
        text,
        '\t\t1FF8DBB01FBA9DE1009DE660 /* dummy.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = dummy.cpp; sourceTree = "<group>"; };\n',
        FILE_REF_SWIFT,
    )
    text = insert_once(
        text,
        '58938401000000000000000F = {isa = PBXBuildFile; fileRef = 58938401000000000000000E; settings = {ATTRIBUTES = (CodeSignOnCopy, ); }; };\n',
        JSC_BUILD + JSC_REF,
    )

    text = replace_once(
        text,
        '58938401000000000000000D\n\t\t\t);',
        '58938401000000000000000D,\n589384010000000000000010\n\t\t\t);',
    )
    text = replace_once(
        text,
        '58938401000000000000000E\n\t\t\t);',
        '58938401000000000000000E,\n589384010000000000000011\n\t\t\t);',
    )
    text = replace_once(
        text,
        '\t\t\t\t1FF8DBB01FBA9DE1009DE660 /* dummy.cpp */,\n\t\t\t\t\n',
        '\t\t\t\t1FF8DBB01FBA9DE1009DE660 /* dummy.cpp */,\n\t\t\t\t1FF8DBB21FBA9DE1009DE661 /* dummy.swift */,\n\t\t\t\t\n',
    )
    text = replace_once(
        text,
        '\t\t\t\t1FF8DBB11FBA9DE1009DE660 /* dummy.cpp in Sources */,\n\t\t\t\t\n',
        '\t\t\t\t1FF8DBB11FBA9DE1009DE660 /* dummy.cpp in Sources */,\n\t\t\t\t1FF8DBB31FBA9DE1009DE661 /* dummy.swift in Sources */,\n\t\t\t\t\n',
    )

    always_embed = '\t\t\t\tALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES;\n'
    swift_version = '\t\t\t\tSWIFT_VERSION = 5.0;\n'
    product_line = '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.MladenStojanovic.dielaughing;\n'
    provisioning_block = '\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "";\n\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";\n'

    if always_embed + product_line not in text:
        text = replace_once(text, product_line, always_embed + product_line)

    if swift_version + '\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";\n' not in text:
        text = replace_once(
            text,
            provisioning_block,
            '\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "";\n' + swift_version + '\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";\n',
        )
    if swift_version + '\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";\n' not in text:
        text = replace_once(
            text,
            provisioning_block,
            '\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "";\n' + swift_version + '\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";\n',
        )

    text = collapse_duplicates(text, always_embed)
    text = collapse_duplicates(text, swift_version)

    if text == original:
        return False

    pbxproj_path.write_text(text)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Patch a Godot-exported iOS Xcode project for AdMob Swift/JavaScriptCore integration.")
    parser.add_argument("export_dir", help="Path to the exported Godot iOS project directory")
    args = parser.parse_args()

    export_dir = Path(args.export_dir).expanduser().resolve()
    pbxproj = export_dir / "dielaughing.xcodeproj" / "project.pbxproj"

    if not pbxproj.is_file():
        print(f"Missing Xcode project file: {pbxproj}", file=sys.stderr)
        return 1

    changed = patch_pbxproj(pbxproj)
    if changed:
        print(f"Patched {pbxproj}")
    else:
        print(f"No changes needed for {pbxproj}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

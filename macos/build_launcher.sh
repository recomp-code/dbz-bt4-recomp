#!/bin/bash
# build_launcher.sh <out>: compiles the Mac launcher (launcher/DBZ_BT4.swift) with the Xcode command line tools' swiftc.
set -e
cd "$(dirname "$0")"
swiftc -O -target arm64-apple-macos14.0 -o "${1:-DBZ_BT4}" launcher/DBZ_BT4.swift

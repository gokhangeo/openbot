#!/usr/bin/env bash
# Reis derleme hazırlığı. apps/mobile klasöründe, "expo prebuild"dan ÖNCE çalışır (Codemagic: rea/codemagic/reis.sh).
# Upstream dosyalarını depoda değiştirmeden, yalnız derleme makinesindeki kopyada OpenBot'un App Group adını
# Reis'inkiyle değiştirir. Böylece günlük upstream birleştirmeleri çakışmaz.
set -euo pipefail
GRUP="group.com.gokhan.asistan.RDYFR8KV2N"
for f in src/shared/lib/app-group.ts plugins/shortcuts/ShortcutData.swift; do
  [ -f "$f" ] || { echo "Uyarı: $f yok (upstream taşımış olabilir)"; continue; }
  perl -pi -e "s/group\\.run\\.openbot\\.mobile/${GRUP}/g" "$f"
  grep -q "$GRUP" "$f" && echo "App Group: $f"
done

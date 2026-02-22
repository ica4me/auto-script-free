#!/bin/bash

# Cek semua script bisa jalan atau tidak(oke/false)
# nano cek-usr-local-sbin.sh
# chmod +x cek-usr-local-sbin.sh
# ./cek-usr-local-sbin.sh

DIR="/usr/local/sbin"

for f in "$DIR"/*; do
    [ -f "$f" ] || continue

    # Ambil shebang (baris pertama)
    first_line=$(head -n1 "$f")

    if [[ "$first_line" == *bash* ]]; then
        bash -n "$f" >/dev/null 2>&1
        status=$?
    elif [[ "$first_line" == *sh* ]]; then
        sh -n "$f" >/dev/null 2>&1
        status=$?
    else
        # Jika bukan script shell atau tidak jelas
        echo "$(basename "$f") : SKIP (bukan shell script)"
        continue
    fi

    if [ $status -eq 0 ]; then
        echo "$(basename "$f") : OK"
    else
        echo "$(basename "$f") : FALSE"
    fi
done
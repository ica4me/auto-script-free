#!/bin/bash
# Script Pemasang Wrapper curl & wget (Case-Insensitive Blocker)

BLOCKED_USER="diah082"

setup_wrapper() {
    local cmd="$1"
    local bin_path
    bin_path=$(command -v "$cmd" 2>/dev/null)
    
    if [ -z "$bin_path" ]; then
        echo "Program $cmd tidak ditemukan di sistem."
        return
    fi

    local real_bin="${bin_path}-real"

    # 1. Cek dan amankan binary asli
    if [ ! -f "$real_bin" ]; then
        # Pastikan file saat ini adalah binary ELF asli, bukan script wrapper gagal sebelumnya
        if file "$bin_path" | grep -q "shell script"; then
            echo "Peringatan: $bin_path sudah berupa script, tapi backup aslinya tidak ada."
            echo "Memperbaiki... menginstal ulang $cmd murni dari repository."
            apt-get install --reinstall -y "$cmd" >/dev/null 2>&1
        fi
        # Ubah nama program asli menjadi *-real
        mv "$bin_path" "$real_bin"
    fi

    # 2. Buat script wrapper baru untuk mencegat eksekusi
    cat > "$bin_path" <<EOF
#!/bin/bash

# Tangkap semua argumen pengguna dan ubah jadi huruf kecil semua
ARGS_LOWER=\$(echo "\$*" | tr '[:upper:]' '[:lower:]')

# Periksa apakah ada pola URL terlarang di dalam argumen
case "\$ARGS_LOWER" in
    *"github.com/$BLOCKED_USER"* | *"githubusercontent.com/$BLOCKED_USER"*)
        echo "[SISTEM BLOKIR] Akses ke repository user: $BLOCKED_USER ditolak!" >&2
        exit 1
        ;;
esac

# Jika aman, operasikan argumen tersebut ke program asli
exec "$real_bin" "\$@"
EOF

    # 3. Beri izin eksekusi
    chmod +x "$bin_path"
    echo "✅ Wrapper sistem untuk '$cmd' berhasil dipasang dan kebal kapitalisasi."
}

echo "Memulai pemasangan System Wrapper..."
setup_wrapper "wget"
setup_wrapper "curl"
echo "Selesai. Silakan lakukan tes unduh ulang."
Berkas ini adalah pengganti bersih untuk binary ws yang terdeteksi berbahaya.

Isi folder:
- ws              : binary Linux amd64 siap pakai
- ws-clean.go     : source code Go
- config.conf     : contoh konfigurasi kompatibel
- ws.service      : contoh systemd service

Fungsi:
- Membaca config.conf
- Membuka listener TCP pada listen_port
- Meneruskan koneksi ke target_host:target_port

Tidak melakukan:
- akses GitHub/Telegram
- penulisan authorized_keys
- chattr
- modifikasi SSH/systemd/Xray

Build ulang:
  CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o ws ws-clean.go

Instalasi cepat:
  mkdir -p /opt/udp-custom
  cp ws config.conf ws.service /opt/udp-custom/
  cp ws.service /etc/systemd/system/ws.service
  systemctl daemon-reload
  systemctl enable --now ws.service

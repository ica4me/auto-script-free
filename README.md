<p align="center">
    ###[ScreenShot Main Menu\]</p>

<p align="center">
 <img src="https://raw.githubusercontent.com/ica4me/auto-script-free/main/dokumentasi/main_menu.png" width="600"/>
</p>
# 📦 Tutorial Instalasi (Step by Step)

**Rekomendasi OS: Debian 11 / Debian 12 (Stable)**

---

## 🖥️ Persyaratan

- VPS KVM / VM full virtualization
- RAM minimal 1 GB (Rekomendasi 2GB atau Lebih)
- Akses root SSH
- Internet stabil
- OS target: Debian 11 / 12 /ubuntu 22.04
- Disarankan VPS kosong / fresh install (Silahkan Rebuild)
- Pointing Cloudflare Sudah di setting

---

## 🔐 **Security Group (Firewall Rules)**

- Open all inbound ports 0-65535
- Open all outbound ports 0-65535
- Allow All Protocol (Any Protocol)

---

## ✅ Urutan Instalasi (Wajib Ikuti)

### 0) Reinstall VPS ke Debian 12 (Opsional)

```bash
wget https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && chmod +x reinstall.sh && bash reinstall.sh debian 12 && reboot
```

Tunggu proses selesai → VPS otomatis reboot.

---

### 1) Update Sistem & Install Screen

Login kembali ke VPS setelah reboot, lalu jalankan update:

```bash
sudo apt update && sudo apt upgrade -y && sudo apt install -y screen wget curl jq
```

Wajib perbaiki Error -bash: sudo: command not found
kalau Tidak proses Install Gagal

```bash
cat <<'EOF' > /usr/local/bin/sudo && chmod +x /usr/local/bin/sudo
#!/bin/sh
if command -v /usr/bin/sudo >/dev/null 2>&1; then
    exec /usr/bin/sudo "$@"
fi
if [ "$(id -u)" -eq 0 ]; then
    exec "$@"
fi
echo "sudo not installed and you are not root" >&2
exit 1
EOF
```

---

### 2) Buat Swap (Rekomendasi)

Jalankan Jika Ram di bawah 4Gb:

```bash
wget https://raw.githubusercontent.com/ica4me/auto-script-free/main/make-swap.sh && chmod +x make-swap.sh && bash make-swap.sh
```

---

### 3) Setup Install (wajib)

Persiapan Sebelum instalasi Utama.

```bash
wget -qO- https://raw.githubusercontent.com/ica4me/auto-script-free/main/install/install-setup.sh | bash
```

Daftarkan IP

```bash
sudo bash -c 'curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 https://raw.githubusercontent.com/ica4me/auto-script-free/main/romsip.sh | bash'
```

---

### 4) Install Auto Script [setup.sh](https://raw.githubusercontent.com/ica4me/auto-script-free/main/setup.sh) (wajib)

```bash
wget https://raw.githubusercontent.com/ica4me/auto-script-free/main/setup.sh
chmod +x setup.sh
screen ./setup.sh
```

Gunakan `screen` agar instalasi tetap berjalan jika SSH terputus.

---

### 5) Finis Install (wajib)

```bash
sudo bash -c 'curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 https://raw.githubusercontent.com/ica4me/auto-script-free/main/install/finish-install.sh | bash'
```

Fix ALL file usr-local-sbin
Penganti perintah (sed -i 's/\r$//' /usr/local/sbin/\*), sed tidak aman.

```bash
wget -qO- https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-error/fix-usr-local-sbin.sh | bash
```

Fix Hproxy dan Nginx

```bash
wget -qO- https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-error/fix-proxy-nginx.sh | bash
```

Jika masih error jalankan ini (Jika error: Ganti Let's Encrypt menjadi ZeroSSL)

```bash
wget -qO- https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-error/zerossl.sh | bash
```

Fix Xray Failed Start (Jika error)

```bash
wget -qO- https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-error/fix-xray.sh | bash
```

---

### 8) Reboot VPS (Opsional)

```bash
m-reboot
```

---

## ✅ Instalasi Selesai

---

## 🛠️ Troubleshooting

### ❌ Script tidak jalan

Pastikan:

- Login sebagai root
- Internet VPS aktif
- Tidak ada firewall blocking

---

### ❌ Instalasi terputus

Gunakan screen:

```bash
screen -r
```

---

### ❌ Tidak bisa login SSH setelah ubah port

Gunakan Port 22/2003/2026

```bash
ssh root@ip-vps -p 2003
```

---

---

## 👤 Mod by / Source

Website:

https://vip.meiyu.my.id/

Github:  
https://github.com/ica4me

Reinstall Script:  
https://github.com/bin456789/reinstall

---

## 📜 Lisensi

Go Free

---

## ⭐ Selesai

Selamat VPS Anda siap digunakan 🚀

<details>
<summary>**Service & Port List**</summary>
<p align="center">
 <img src="https://raw.githubusercontent.com/ica4me/auto-script-free/main/dokumentasi/service-port-list.png" width="300"/>
</p>
</details>

<details>
<summary>**Setting CloudFlare**</summary>

- Pointing Domain

![](https://raw.githubusercontent.com/ica4me/auto-script-free/main/dokumentasi/019c7444-f003-7799-bcc0-80f9c61acd84/image.png)

- TLS/SSL Harus pilih yang FULL![](https://raw.githubusercontent.com/ica4me/auto-script-free/main/dokumentasi/019c7447-2fcf-750a-b222-53b91b110896/image.png)
- Always HTTPS harus dimatiin![](https://raw.githubusercontent.com/ica4me/auto-script-free/main/dokumentasi/019c7449-e919-7198-96c0-e30138ba6b39/image.png)
- Network aktifin WebSocket dan gRPC![](https://raw.githubusercontent.com/ica4me/auto-script-free/main/dokumentasi/019c744b-8d70-756c-bbeb-4ee5a045658d/image.png)
- Tambahkan wilcard agar support bug pakai wildcard

![](https://raw.githubusercontent.com/ica4me/auto-script-free/main/dokumentasi/019c7450-2e15-7048-8eaf-465058c8b690/image.png)

</details>

## SUPPORT & DONASI

<p align="center">
 <img src="https://raw.githubusercontent.com/ica4me/auto-script-free/main/dokumentasi/019c7450-a26a-7087-9cdc-20bce874e9ef/Qris_Dana_Najm.jpeg" width="300"/>
</p>

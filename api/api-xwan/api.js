const express = require("express");
const { exec } = require("child_process");
const app = express();
const PORT = 5888;

// Middleware untuk parsing query string
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

// Fungsi untuk parsing output shell ke JSON
function parseSSHOutput(output) {
    const extract = (pattern) => {
        const match = output.match(pattern);
        return match ? match[1].trim() : "";
    };

    return {
        username: extract(/Remark\s+:\s+(\S+)/),
        password: extract(/Password\s+:\s+(\S+)/),
        ip_limit: extract(/Limit Ip\s+:\s+(.+)/),
        domain: extract(/Domain\s+:\s+(\S+)/),
        ns_domain: extract(/Ns Domain\s+:\s+(.+)/),
		pubkey: extract(/Pub Key\s+:\s+(.+)/),
	    isp: extract(/ISP\s+:\s+(.+)/),
        expired: extract(/Expiry in\s+:\s+(.+)/),
		uuid: extract(/Key\s+:\s+(.+)/),
		quota: extract(/Limit Quota\s+:\s+(.+)/),
		vmess_tls_link: extract(/Link TLS\s+:\s+(.+)/),
		vmess_nontls_link: extract(/Link WS\s+:\s+(.+)/),
		vmess_grpc_link: extract(/Link GRPC\s+:\s+(.+)/),
		vless_tls_link: extract(/Link TLS\s+:\s+(.+)/),
		vless_nontls_link: extract(/Link WS\s+:\s+(.+)/),
		vless_grpc_link: extract(/Link GRPC\s+:\s+(.+)/),
		trojan_tls_link: extract(/Link TLS\s+:\s+(.+)/),
		trojan_nontls_link1: extract(/Link WS\s+:\s+(.+)/),
		trojan_grpc_link: extract(/Link GRPC\s+:\s+(.+)/),
		ss_link_nontls: extract(/Link WS\s+:\s+(.+)/),
		ss_link_ws: extract(/Link TLS\s+:\s+(.+)/),
		ss_link_grpc: extract(/Link GRPC\s+:\s+(.+)/),
    };
}

const AUTH_KEY = process.env.AUTH_KEY;

app.get("/createssh", (req, res) => {
    const { user, password, exp, iplimit, auth } = req.query;

    // Validasi autentikasi
    if (!AUTH_KEY) {
        return res.status(500).json({ status: "error", message: "AUTH_KEY not set" });
    }

    if (auth !== AUTH_KEY) {
        return res.status(403).json({ status: "error", message: "Unauthorized" });
    }


    // Validasi input
    if (!user || !password || !exp || !iplimit) {
        return res.status(400).json({ status: "error", message: "Missing parameters" });
    }

    // Eksekusi skrip shell untuk membuat akun SSH
    exec(`bash create_ssh.sh ${user} ${password} ${iplimit} ${exp}`, (error, stdout, stderr) => {
        if (error) {
            return res.json({ status: "error", message: stderr });
        }

        // Parsing output shell menjadi JSON
        const sshData = parseSSHOutput(stdout);

        res.json({
            status: "success",
            message: `Akun SSH berhasil dibuat untuk ${sshData.username}`,
            data: sshData
        });
    });
});

app.get("/createvmess", (req, res) => {
    const { user, exp, iplimit, quota, auth } = req.query;

    // Validasi autentikasi
    if (!AUTH_KEY) {
        return res.status(500).json({ status: "error", message: "AUTH_KEY not set" });
    }

    if (auth !== AUTH_KEY) {
        return res.status(403).json({ status: "error", message: "Unauthorized" });
    }


    // Validasi input
    if (!user || !exp || !quota || !iplimit) {
        return res.status(400).json({ status: "error", message: "Missing parameters" });
    }

    // Eksekusi skrip shell untuk membuat akun SSH
    exec(`bash create_vmess.sh ${user} ${exp} ${iplimit} ${quota} `, (error, stdout, stderr) => {
        if (error) {
            return res.json({ status: "error", message: stderr });
        }

        // Parsing output shell menjadi JSON
        const vmessData = parseSSHOutput(stdout);

        res.json({
            status: "success",
            message: `Akun Vmess berhasil dibuat untuk ${vmessData.username}`,
            data: vmessData
        });
    });
});

app.get("/createvless", (req, res) => {
    const { user, exp, iplimit, quota, auth } = req.query;

    // Validasi autentikasi
    if (!AUTH_KEY) {
        return res.status(500).json({ status: "error", message: "AUTH_KEY not set" });
    }

    if (auth !== AUTH_KEY) {
        return res.status(403).json({ status: "error", message: "Unauthorized" });
    }


    // Validasi input
    if (!user || !exp || !quota || !iplimit) {
        return res.status(400).json({ status: "error", message: "Missing parameters" });
    }

    // Eksekusi skrip shell untuk membuat akun SSH
    exec(`bash create_vless.sh ${user} ${exp} ${iplimit} ${quota} `, (error, stdout, stderr) => {
        if (error) {
            return res.json({ status: "error", message: stderr });
        }

        // Parsing output shell menjadi JSON
        const vlessData = parseSSHOutput(stdout);

        res.json({
            status: "success",
            message: `Akun Vless berhasil dibuat untuk ${vlessData.username}`,
            data: vlessData
        });
    });
});

app.get("/createtrojan", (req, res) => {
    const { user, exp, iplimit, quota, auth } = req.query;

    // Validasi autentikasi
    if (!AUTH_KEY) {
        return res.status(500).json({ status: "error", message: "AUTH_KEY not set" });
    }

    if (auth !== AUTH_KEY) {
        return res.status(403).json({ status: "error", message: "Unauthorized" });
    }


    // Validasi input
    if (!user || !exp || !quota || !iplimit) {
        return res.status(400).json({ status: "error", message: "Missing parameters" });
    }

    // Eksekusi skrip shell untuk membuat akun SSH
    exec(`bash create_trojan.sh ${user} ${exp} ${iplimit} ${quota} `, (error, stdout, stderr) => {
        if (error) {
            return res.json({ status: "error", message: stderr });
        }

        // Parsing output shell menjadi JSON
        const trojanData = parseSSHOutput(stdout);

        res.json({
            status: "success",
            message: `Akun Trojan berhasil dibuat untuk ${trojanData.username}`,
            data: trojanData
        });
    });
});

app.get("/createshadowsocks", (req, res) => {
    const { user, exp, iplimit, quota, auth } = req.query;

    // Validasi autentikasi
    if (!AUTH_KEY) {
        return res.status(500).json({ status: "error", message: "AUTH_KEY not set" });
    }

    if (auth !== AUTH_KEY) {
        return res.status(403).json({ status: "error", message: "Unauthorized" });
    }


    // Validasi input
    if (!user || !exp || !quota || !iplimit) {
        return res.status(400).json({ status: "error", message: "Missing parameters" });
    }

    // Eksekusi skrip shell untuk membuat akun SSH
    exec(`bash create_ss.sh ${user} ${exp} ${iplimit} ${quota} `, (error, stdout, stderr) => {
        if (error) {
            return res.json({ status: "error", message: stderr });
        }

        // Parsing output shell menjadi JSON
        const shadowsocksData = parseSSHOutput(stdout);

        res.json({
            status: "success",
            message: `Akun Shadowsocks berhasil dibuat untuk ${shadowsocksData.username}`,
            data: shadowsocksData
        });
    });
});

app.get("/trialssh", (req, res) => {
	const { auth } = req.query;
    // Validasi autentikasi
    if (!AUTH_KEY) {
        return res.status(500).json({ status: "error", message: "AUTH_KEY not set" });
    }

    if (auth !== AUTH_KEY) {
        return res.status(403).json({ status: "error", message: "Unauthorized" });
    }

    // Eksekusi skrip shell untuk membuat akun SSH
    exec(`bash trial_ssh.sh`, (error, stdout, stderr) => {
        if (error) {
            return res.json({ status: "error", message: stderr });
        }

        // Parsing output shell menjadi JSON
        const sshData = parseSSHOutput(stdout);

        res.json({
            status: "success",
            message: `Akun Trial SSH berhasil dibuat untuk ${sshData.username}`,
            data: sshData
        });
    });
});

app.get("/trialvmess", (req, res) => {
	const { auth } = req.query;
    // Validasi autentikasi
    if (!AUTH_KEY) {
        return res.status(500).json({ status: "error", message: "AUTH_KEY not set" });
    }

    if (auth !== AUTH_KEY) {
        return res.status(403).json({ status: "error", message: "Unauthorized" });
    }

    // Eksekusi skrip shell untuk membuat akun SSH
    exec(`bash trial_vmess.sh`, (error, stdout, stderr) => {
        if (error) {
            return res.json({ status: "error", message: stderr });
        }

        // Parsing output shell menjadi JSON
        const vmessData = parseSSHOutput(stdout);

        res.json({
            status: "success",
            message: `Akun Trial Vmess berhasil dibuat untuk ${vmessData.username}`,
            data: vmessData
        });
    });
});

app.get("/trialvless", (req, res) => {
	const { auth } = req.query;
    // Validasi autentikasi
    if (!AUTH_KEY) {
        return res.status(500).json({ status: "error", message: "AUTH_KEY not set" });
    }

    if (auth !== AUTH_KEY) {
        return res.status(403).json({ status: "error", message: "Unauthorized" });
    }

    // Eksekusi skrip shell untuk membuat akun SSH
    exec(`bash trial_vless.sh`, (error, stdout, stderr) => {
        if (error) {
            return res.json({ status: "error", message: stderr });
        }

        // Parsing output shell menjadi JSON
        const vlessData = parseSSHOutput(stdout);

        res.json({
            status: "success",
            message: `Akun Trial Vless berhasil dibuat untuk ${vlessData.username}`,
            data: vlessData
        });
    });
});

app.get("/trialtrojan", (req, res) => {
	const { auth } = req.query;
    // Validasi autentikasi
    if (!AUTH_KEY) {
        return res.status(500).json({ status: "error", message: "AUTH_KEY not set" });
    }

    if (auth !== AUTH_KEY) {
        return res.status(403).json({ status: "error", message: "Unauthorized" });
    }

    // Eksekusi skrip shell untuk membuat akun SSH
    exec(`bash trial_trojan.sh`, (error, stdout, stderr) => {
        if (error) {
            return res.json({ status: "error", message: stderr });
        }

        // Parsing output shell menjadi JSON
        const trojanData = parseSSHOutput(stdout);

        res.json({
            status: "success",
            message: `Akun Trial Trojan berhasil dibuat untuk ${trojanData.username}`,
            data: trojanData
        });
    });
});

app.get("/trialshadowsocks", (req, res) => {
	const { auth } = req.query;
    // Validasi autentikasi
    if (!AUTH_KEY) {
        return res.status(500).json({ status: "error", message: "AUTH_KEY not set" });
    }

    if (auth !== AUTH_KEY) {
        return res.status(403).json({ status: "error", message: "Unauthorized" });
    }

    // Eksekusi skrip shell untuk membuat akun SSH
    exec(`bash trial_ss.sh`, (error, stdout, stderr) => {
        if (error) {
            return res.json({ status: "error", message: stderr });
        }

        // Parsing output shell menjadi JSON
        const shadowsocksData = parseSSHOutput(stdout);

        res.json({
            status: "success",
            message: `Akun Trial shadowsocks berhasil dibuat untuk ${shadowsocksData.username}`,
            data: shadowsocksData
        });
    });
});

app.get("/renewssh", (req, res) => {
    const { user, exp, iplimit, auth } = req.query;

    const cmd = `sudo bash /usr/bin/api-xwan/renew_ssh.sh ${user} ${iplimit} ${exp}`;

    exec(cmd, (error, stdout, stderr) => {
        if (error) {
            console.error("Error:", stderr);
            
            return res.json({ 
                status: "error", 
                message: stdout || stderr || "Gagal memperbarui akun SSH. Pastikan user masih ada." 
            });
        }

        
        try {
            const sshData = parseSSHOutput(stdout); 
            
            if (!sshData.username) {
                 console.error("Failed to parse SSH data from stdout:", stdout);
                 return res.status(500).json({ status: "error", message: "Failed to parse renew_ssh.sh output." });
            }

            return res.json({
                status: "success",
                message: `Renew SSH berhasil dibuat untuk ${sshData.username}`,
                data: sshData 
            });
        } catch (e) {
            console.error("Error parsing output in /renewssh:", e.message, "Output:", stdout);
            return res.status(500).json({
                status: "error",
                message: "Internal server error during renew output parsing."
            });
        }
    });
});

app.get("/renewvmess", (req, res) => {
    const { user, exp, iplimit, quota, auth } = req.query;

    // Validasi autentikasi
    if (!AUTH_KEY) {
        return res.status(500).json({ status: "error", message: "AUTH_KEY not set" });
    }

    if (auth !== AUTH_KEY) {
        return res.status(403).json({ status: "error", message: "Unauthorized" });
    }


    // Validasi input
    if (!user || !exp || !iplimit || !quota) {
        return res.status(400).json({ status: "error", message: "Missing parameters" });
    }

    // Eksekusi skrip shell untuk membuat akun SSH
    exec(`bash renew_vmess.sh ${user} ${exp} ${iplimit} ${quota}`, (error, stdout, stderr) => {
        if (error) {
            return res.json({ status: "error", message: "Gagal memperbarui akun VMESS. Pastikan user masih ada." });
        }

        // Parsing output shell menjadi JSON
        const vmessData = parseSSHOutput(stdout);

        res.json({
            status: "success",
            message: `Renew Vmess berhasil dibuat untuk ${vmessData.username}`,
            data: vmessData
        });
    });
});

app.get("/renewvless", (req, res) => {
    const { user, exp, iplimit, quota, auth } = req.query;

    // Validasi autentikasi
    if (!AUTH_KEY) {
        return res.status(500).json({ status: "error", message: "AUTH_KEY not set" });
    }

    if (auth !== AUTH_KEY) {
        return res.status(403).json({ status: "error", message: "Unauthorized" });
    }


    // Validasi input
    if (!user || !exp || !iplimit || !quota) {
        return res.status(400).json({ status: "error", message: "Missing parameters" });
    }

    // Eksekusi skrip shell untuk membuat akun SSH
    exec(`bash renew_vless.sh ${user} ${exp} ${iplimit} ${quota}`, (error, stdout, stderr) => {
        if (error) {
            return res.json({ status: "error", message: "Gagal memperbarui akun VLESS. Pastikan user masih ada." });
        }

        // Parsing output shell menjadi JSON
        const vlessData = parseSSHOutput(stdout);

        res.json({
            status: "success",
            message: `Renew Vless berhasil dibuat untuk ${vlessData.username}`,
            data: vlessData
        });
    });
});

app.get("/renewtrojan", (req, res) => {
    const { user, exp, iplimit, quota, auth } = req.query;

    // Validasi autentikasi
    if (!AUTH_KEY) {
        return res.status(500).json({ status: "error", message: "AUTH_KEY not set" });
    }

    if (auth !== AUTH_KEY) {
        return res.status(403).json({ status: "error", message: "Unauthorized" });
    }


    // Validasi input
    if (!user || !exp || !iplimit || !quota) {
        return res.status(400).json({ status: "error", message: "Missing parameters" });
    }

    // Eksekusi skrip shell untuk membuat akun SSH
    exec(`bash renew_trojan.sh ${user} ${exp} ${iplimit} ${quota}`, (error, stdout, stderr) => {
        if (error) {
            return res.json({ status: "error", message: "Gagal memperbarui akun TROJAN. Pastikan user masih ada." });
        }

        // Parsing output shell menjadi JSON
        const trojanData = parseSSHOutput(stdout);

        res.json({
            status: "success",
            message: `Renew Trojan berhasil dibuat untuk ${trojanData.username}`,
            data: trojanData
        });
    });
});

app.get("/renewshadowsocks", (req, res) => {
    const { user, exp, iplimit, quota, auth } = req.query;

    // Validasi autentikasi
    if (!AUTH_KEY) {
        return res.status(500).json({ status: "error", message: "AUTH_KEY not set" });
    }

    if (auth !== AUTH_KEY) {
        return res.status(403).json({ status: "error", message: "Unauthorized" });
    }


    // Validasi input
    if (!user || !exp || !iplimit || !quota) {
        return res.status(400).json({ status: "error", message: "Missing parameters" });
    }

    // Eksekusi skrip shell untuk membuat akun SSH
    exec(`bash renew_ss.sh ${user} ${exp} ${iplimit} ${quota}`, (error, stdout, stderr) => {
        if (error) {
            return res.json({ status: "error", message: "Gagal memperbarui akun Shadowsocks. Pastikan user masih ada." });
        }

        // Parsing output shell menjadi JSON
        const shadowsocksData = parseSSHOutput(stdout);

        res.json({
            status: "success",
            message: `Renew Shadowsocks berhasil dibuat untuk ${shadowsocksData.username}`,
            data: shadowsocksData
        });
    });
});

// Menjalankan server
app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server berjalan di port ${PORT}`);
});

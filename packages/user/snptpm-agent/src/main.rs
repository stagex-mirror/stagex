// snptpm-agent: dual attestation agent (TPM2 + SEV-SNP)
// Zero external dependencies. Serves combined attestation on port 9003.
//
// Endpoints:
//   GET /attest     - JSON: { "tpm": ..., "snp": ... }
//   GET /tpm/pcrs   - TPM2 PCR values (sha256:0-15)
//   GET /snp/report - SEV-SNP attestation report (hex)
//   GET /health     - {"status":"ok"}

use std::io::{Read, Write};
use std::net::TcpListener;
use std::process::Command;

const PORT: u16 = 9003;

fn run_cmd(cmd: &str, args: &[&str]) -> Result<Vec<u8>, String> {
    let output = Command::new(cmd)
        .args(args)
        .output()
        .map_err(|e| format!("exec {} failed: {}", cmd, e))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("{} exited {}: {}", cmd, output.status, stderr.trim()));
    }
    Ok(output.stdout)
}

fn get_tpm_pcrs() -> Result<String, String> {
    let out = run_cmd("tpm2_pcrread", &["sha256:0-15"])?;
    Ok(String::from_utf8_lossy(&out).to_string())
}

fn get_snp_report() -> Result<String, String> {
    let out = run_cmd("snpguest", &["report"])?;
    // snpguest may output hex text or raw binary; normalize to hex
    if let Ok(text) = std::str::from_utf8(&out) {
        let trimmed = text.trim();
        if !trimmed.is_empty() && trimmed.chars().all(|c| c.is_ascii_hexdigit() || c == ' ' || c == '\n') {
            return Ok(trimmed.replace('\n', "").replace(' ', ""));
        }
        // text but not pure hex, return as-is
        return Ok(trimmed.to_string());
    }
    // raw binary: hex-encode
    Ok(bytes_to_hex(&out))
}

fn bytes_to_hex(data: &[u8]) -> String {
    let mut s = String::with_capacity(data.len() * 2);
    for b in data {
        s.push_str(&format!("{:02x}", b));
    }
    s
}

fn json_escape(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out
}

fn respond(status: u16, body: &str) -> String {
    let status_text = match status {
        200 => "OK",
        404 => "Not Found",
        500 => "Internal Server Error",
        _ => "OK",
    };
    format!(
        "HTTP/1.1 {} {}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        status, status_text, body.len(), body
    )
}

fn handle(path: &str) -> (u16, String) {
    match path {
        "/health" => (200, r#"{"status":"ok"}"#.to_string()),

        "/attest" => {
            let tpm = get_tpm_pcrs();
            let snp = get_snp_report();

            let tpm_val = match &tpm {
                Ok(s) => format!("\"{}\"", json_escape(s)),
                Err(e) => format!("\"error:{}\"", json_escape(e)),
            };
            let snp_val = match &snp {
                Ok(s) => format!("\"{}\"", json_escape(s)),
                Err(e) => format!("\"error:{}\"", json_escape(e)),
            };

            (200, format!(r#"{{"tpm":{},"snp":{}}}"#, tpm_val, snp_val))
        }

        "/tpm/pcrs" => match get_tpm_pcrs() {
            Ok(s) => (200, format!("\"{}\"", json_escape(&s))),
            Err(e) => (500, format!("\"{}\"", json_escape(&e))),
        },

        "/snp/report" => match get_snp_report() {
            Ok(s) => (200, format!("\"{}\"", json_escape(&s))),
            Err(e) => (500, format!("\"{}\"", json_escape(&e))),
        },

        _ => (404, r#"{"error":"not found"}"#.to_string()),
    }
}

fn main() {
    let addr = format!("0.0.0.0:{}", PORT);
    let listener = match TcpListener::bind(&addr) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("snptpm-agent: bind {} failed: {}", addr, e);
            std::process::exit(1);
        }
    };

    eprintln!("snptpm-agent: listening on {}", addr);

    for stream in listener.incoming() {
        if let Ok(mut stream) = stream {
            let mut buf = [0u8; 1024];
            let n = match stream.read(&mut buf) {
                Ok(n) if n > 0 => n,
                _ => continue,
            };
            let request = String::from_utf8_lossy(&buf[..n]);
            let path = request
                .split_whitespace()
                .nth(1)
                .unwrap_or("/")
                .to_string();

            let (status, body) = handle(&path);
            let response = respond(status, &body);
            let _ = stream.write_all(response.as_bytes());
            let _ = stream.flush();
        }
    }
}

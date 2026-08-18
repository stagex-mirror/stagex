// elscan — UEFI TPM2 event log parser (TCG 2.0 Crypto Agile format)
//
// Input: raw /dev/mem dump taken at the efi.tpm_log address
// (from `dmesg | grep TPMEventLog`). The dump begins with
// struct linux_efi_tpm_eventlog { u32 size; u32 preboot; u8 version; u8 log[] }
// but stream alignment has been observed to be off by a few bytes, so the
// parser locates the Spec ID Event signature by scanning and derives the
// first event from it.
//
// Format (include/linux/tpm_eventlog.h + TCG Platform TPM Profile 2.0):
//   FIRST event (Spec ID) = struct tcg_pcr_event:
//     u32 pcr_idx      (must be 0)
//     u32 event_type   (must be 3, EV_SCI_CRTM_VERSION)
//     u8  digest[20]   (SHA-1, all zeros)
//     u32 event_size
//     u8  event[]      = Spec ID event:
//       u8   signature[16] = "Spec ID Event03\0"
//       u32  platform_class
//       u8   minor, major, errata, uintnsize
//       u32  num_algs
//       { u16 alg_id; u16 digest_size; }[num_algs]
//   SUBSEQUENT events = struct tcg_pcr_event2_head:
//     u32 pcr_idx, u32 event_type, u32 count
//     per digest: u16 alg_id + digest_size bytes (size from Spec ID table)
//     u32 event_size, u8 event[event_size]
//   Terminated by an all-zero event header.
//
// Usage: elscan <dump-file>
//   elscan <dump-file> --hex   also hexdumps every event's data

use std::env;
use std::fs;
use std::process;

const SIG: &[u8; 16] = b"Spec ID Event03\0";
const PCR_MAX: u32 = 24;
const MAX_EVENTS: usize = 1024;
const MAX_EVENT_SIZE: usize = 8 * 1024 * 1024;
const SCAN_LIMIT: usize = 65536;

#[derive(Clone, Debug)]
struct Alg {
    id: u16,
    size: u16,
}

#[derive(Clone, Debug)]
struct Event {
    offset: usize,
    pcr: u32,
    event_type: u32,
    digests: Vec<(u16, Vec<u8>)>,
    data: Vec<u8>,
}

fn r16(d: &[u8], o: usize) -> u16 {
    u16::from_le_bytes([d[o], d[o + 1]])
}

fn r32(d: &[u8], o: usize) -> u32 {
    u32::from_le_bytes([d[o], d[o + 1], d[o + 2], d[o + 3]])
}

fn alg_name(id: u16) -> &'static str {
    match id {
        0x0004 => "SHA1",
        0x000B => "SHA256",
        0x000C => "SHA384",
        0x000D => "SHA512",
        0x0012 => "SHA3-256",
        0x0013 => "SHA3-384",
        0x0014 => "SHA3-512",
        _ => "UNKNOWN",
    }
}

fn etype_name(t: u32) -> &'static str {
    match t {
        0 => "EV_NO_ACTION",
        1 => "EV_SEPARATOR",
        2 => "EV_POST_CODE",
        3 => "EV_SCI_CRTM_VERSION",
        4 => "EV_IPL",
        5 => "EV_IPL_CAA",
        6 => "EV_IPL_COMPACT_HASH",
        7 => "EV_IPL_DIGEST",
        8 => "EV_IPL_CRTM_CONTENTS",
        9 => "EV_IPL_CRTM_SIZE",
        10 => "EV_IPL_DIGEST2",
        11 => "EV_NON_HOST_CONFIG",
        12 => "EV_PLATFORM_FIRMWARE_CONFIG",
        13 => "EV_SCI_CRTM_VERSION2",
        14 => "EV_CPU_MODEL",
        15 => "EV_CPU_LEAF7",
        16 => "EV_OEM_ASSIGNED",
        17 => "EV_FIRMWARE_IMAGE",
        18 => "EV_FIRMWARE_CONFIG",
        _ => "UNKNOWN",
    }
}

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{:02x}", x)).collect()
}

fn ascii(b: &[u8]) -> String {
    b.iter()
        .map(|x| if x.is_ascii_graphic() || *x == b' ' { *x as char } else { '.' })
        .collect()
}

// Locate the Spec ID signature and parse the log starting 32 bytes before it
// (the tcg_pcr_event fixed header: pcr_idx + event_type + digest[20] + event_size).
fn find_log_start(data: &[u8]) -> Option<usize> {
    let scan_end = data.len().min(SCAN_LIMIT);
    for i in 0..scan_end.saturating_sub(SIG.len()) {
        if &data[i..i + SIG.len()] == SIG {
            let first = i.checked_sub(32)?;
            // Validate the Spec ID event header
            if r32(data, first) != 0 {
                continue;
            }
            if r32(data, first + 4) != 3 {
                continue;
            }
            let digest = &data[first + 8..first + 28];
            if digest.iter().any(|&b| b != 0) {
                continue;
            }
            let ev_size = r32(data, first + 28) as usize;
            if ev_size < 28 || ev_size > 1024 {
                continue;
            }
            if first + 32 + ev_size > data.len() {
                continue;
            }
            return Some(first);
        }
    }
    None
}

fn parse(data: &[u8], start: usize) -> (Vec<Event>, Option<usize>) {
    // --- Spec ID event ---
    let spec_size = r32(data, start + 28) as usize;
    let spec = &data[start + 32..start + 32 + spec_size];
    let platform_class = r32(spec, 16);
    let minor = spec[20];
    let major = spec[21];
    let errata = spec[22];
    let uintnsize = spec[23];
    let num_algs = r32(spec, 24) as usize;
    let mut algs: Vec<Alg> = Vec::new();
    if 28 + 4 * num_algs > spec.len() {
        eprintln!("spec id: alg table truncated");
        process::exit(1);
    }
    for i in 0..num_algs {
        let off = 28 + 4 * i;
        algs.push(Alg { id: r16(spec, off), size: r16(spec, off + 2) });
    }

    println!("=== Spec ID Event (at offset {}) ===", start);
    println!(
        "  platform_class={:#x} version {}.{} errata={} uintn={} num_algs={}",
        platform_class, major, minor, errata, uintnsize, num_algs
    );
    for a in &algs {
        println!("    {:04x} {} ({})", a.id, alg_name(a.id), a.size);
    }

    let mut events: Vec<Event> = Vec::new();
    let mut off = start + 32 + spec_size;

    // --- crypto agile events ---
    for _ in 0..MAX_EVENTS {
        if off + 12 > data.len() {
            break;
        }
        let pcr = r32(data, off);
        let etype = r32(data, off + 4);
        let count = r32(data, off + 8);
        if pcr == 0 && etype == 0 && count == 0 {
            // terminator: pcr_idx, event_type, count, event_size(0)
            let term_size = if off + 16 <= data.len() { r32(data, off + 12) } else { 0 };
            if term_size == 0 {
                events.push(Event {
                    offset: off,
                    pcr: 0,
                    event_type: 0,
                    digests: vec![],
                    data: vec![],
                });
                return (events, Some(off + 16));
            }
            eprintln!("terminator with nonzero event_size at offset {}", off);
            return (events, None);
        }
        if pcr >= PCR_MAX || count as usize != num_algs {
            eprintln!(
                "invalid event at offset {}: pcr={} type={} count={} (expected {} algs)",
                off, pcr, etype, count, num_algs
            );
            return (events, None);
        }
        let mut di = off + 12;
        let mut digests = Vec::new();
        let mut bad = false;
        for _ in 0..count as usize {
            if di + 2 > data.len() {
                bad = true;
                break;
            }
            let aid = r16(data, di);
            di += 2;
            let sz = match algs.iter().find(|a| a.id == aid) {
                Some(a) => a.size as usize,
                None => {
                    eprintln!("unknown alg {:04x} in event at offset {}", aid, off);
                    bad = true;
                    break;
                }
            };
            if di + sz > data.len() {
                bad = true;
                break;
            }
            digests.push((aid, data[di..di + sz].to_vec()));
            di += sz;
        }
        if bad {
            return (events, None);
        }
        let ev_size = r32(data, di) as usize;
        if ev_size > MAX_EVENT_SIZE {
            eprintln!("event_size {} implausible at offset {}", ev_size, off);
            return (events, None);
        }
        if di + 4 + ev_size > data.len() {
            eprintln!("event data truncated at offset {}", off);
            return (events, None);
        }
        let ev_data = data[di + 4..di + 4 + ev_size].to_vec();
        events.push(Event { offset: off, pcr, event_type: etype, digests, data: ev_data });
        off = di + 4 + ev_size;
    }
    eprintln!("hit event limit without terminator");
    (events, None)
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 || args.len() > 3 {
        eprintln!("usage: elscan <dump-file> [--hex]");
        process::exit(1);
    }
    let show_hex = args.iter().any(|a| a == "--hex");

    let data = match fs::read(&args[1]) {
        Ok(d) => d,
        Err(e) => {
            eprintln!("error: cannot read {}: {}", args[1], e);
            process::exit(1);
        }
    };
    println!("dump: {} bytes", data.len());

    // Report the header if it looks sane (best-effort, not authoritative).
    if data.len() >= 9 {
        let size = r32(&data, 0);
        let preboot = r32(&data, 4);
        let ver = data[8];
        println!(
            "header @0: size={} preboot={} version={} (log would start at 9)",
            size, preboot, ver
        );
    }

    let start = match find_log_start(&data) {
        Some(s) => {
            println!("spec id signature found; first event at offset {}\n", s);
            s
        }
        None => {
            eprintln!("error: no valid Spec ID Event signature found");
            process::exit(1);
        }
    };

    let (events, end) = parse(&data, start);
    if end.is_none() {
        eprintln!("warning: chain did not terminate cleanly; printing {} events anyway", events.len());
    }

    println!("\n=== Events: {} ===", events.len());
    for (i, e) in events.iter().enumerate() {
        if e.data.is_empty() && e.digests.is_empty() {
            println!("[{:3}] off={:5} TERMINATOR", i, e.offset);
            continue;
        }
        println!(
            "[{:3}] off={:5} PCR {:2} {:22}",
            i, e.offset, e.pcr, etype_name(e.event_type)
        );
        for (aid, d) in &e.digests {
            println!("        {:6} {} = {}", "", alg_name(*aid), hex(d));
        }
        if !e.data.is_empty() {
            let n = e.data.len().min(120);
            println!("        data({} bytes): {}", e.data.len(), ascii(&e.data[..n]));
            if show_hex {
                for c in e.data.chunks(16) {
                    let o = c.as_ptr() as usize - e.data.as_ptr() as usize;
                    println!(
                        "          {:06x}  {}  |{}|",
                        o,
                        c.iter().map(|x| format!("{:02x}", x)).collect::<Vec<_>>().join(" "),
                        ascii(c)
                    );
                }
            }
        }
    }

    if let Some(end) = end {
        println!("\nlog ends at offset {} ({} bytes)", end, end - start);
    }
}

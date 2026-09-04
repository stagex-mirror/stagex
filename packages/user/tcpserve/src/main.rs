// tcpserve — minimal serial TCP listener (replaces busybox tcpsvd).
//
// Usage: tcpserve <host> <port> <command> [args...]
//
// Binds <host>:<port>. For each accepted connection, in turn, runs
// <command> with the connection as the child's stdin and stdout
// (the child's stderr is inherited — redirect this process's stderr to
// a log file). One connection at a time: the next connection is accepted
// only after the current command exits. std-only.
//
// This is the TCP frontend for tinysshd, which is a stdin/stdout SSH
// server with no port of its own.

use std::fs::File;
use std::net::TcpListener;
use std::os::unix::io::{FromRawFd, IntoRawFd};
use std::process::Command;

fn badusage() -> ! {
    eprintln!("usage: tcpserve <host> <port> <command> [args...]");
    std::process::exit(2);
}

fn main() {
    let mut args = std::env::args();
    let _prog = args.next().expect("program name");
    let host = args.next().unwrap_or_else(|| badusage());
    let port: u16 = args
        .next()
        .unwrap_or_else(|| badusage())
        .parse()
        .unwrap_or_else(|_| badusage());
    let cmd = args.next().unwrap_or_else(|| badusage());
    let cmd_args: Vec<String> = args.collect();

    let listener = match TcpListener::bind((host.as_str(), port)) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("tcpserve: bind {host}:{port} failed: {e}");
            std::process::exit(1);
        }
    };
    eprintln!("tcpserve: listening on {host}:{port}");

    for stream in listener.incoming() {
        let stream = match stream {
            Ok(s) => s,
            Err(e) => {
                eprintln!("tcpserve: accept failed: {e}");
                continue;
            }
        };
        let addr = match stream.peer_addr() {
            Ok(a) => a.to_string(),
            Err(_) => String::from("?"),
        };
        eprintln!("tcpserve: connection from {addr}; running {cmd}");

        // Two owned handles over one full-dup socket: the clone becomes
        // the child's stdin (reads), the original the child's stdout
        // (writes). Each stream is consumed via into_raw_fd(); the File
        // takes ownership of that fd, and Command dups it into the
        // child's fd 0 / fd 1.
        let stdin_side = match stream.try_clone() {
            Ok(c) => c,
            Err(e) => {
                eprintln!("tcpserve: clone failed: {e}");
                continue;
            }
        };
        let stdin_file = unsafe { File::from_raw_fd(stdin_side.into_raw_fd()) };
        let stdout_file = unsafe { File::from_raw_fd(stream.into_raw_fd()) };

        let status = match Command::new(&cmd)
            .args(&cmd_args)
            .stdin(stdin_file)
            .stdout(stdout_file)
            .status()
        {
            Ok(s) => s,
            Err(e) => {
                eprintln!("tcpserve: spawn {cmd} failed: {e}");
                continue;
            }
        };
        if !status.success() {
            eprintln!("tcpserve: {cmd} exited with {status}");
        }
    }
}

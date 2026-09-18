# verify-execd-stack — Phase-4 verify runbook (shell-free execd enclave)

The enclave host OS is shell-free: nit (PID 1) unpacks the erofs, mounts
runtime filesystems, then execs `execd` (PID 1 after execve). execd runs
exactly the dev units `lo`, `dhcp`, `enclaved`, `sshdt`, `bootproofd` over the
pure depends-graph. No dash/ash/brush init, no inittab, no rcS, no S??*, no
`.sh` scripts at boot.

- **enclaved** — single no-arg daemon that owns the hardware (`/dev/tpmrm0` |
  `/dev/tpm0` + `/dev/sev-guest`). Startup: serve → measure → userdata → disk
  → user → ready → serve. Evidence socket `SOCKET_PATH=/run/enclaved/sock`
  (0700 dir, 0600 sock), `READY_PATH=/run/enclaved/ready` (written after the
  boot work). Extends PCR 11 with SHA-256 of the system partition exactly once
  (`SKIP no-partition` on the ESP-only disk). `restart` = No by design: a
  respawn would double-extend PCR 11 and break the verifier's replay.
- **bootproofd** — the ONLY HTTP face: 0.0.0.0:443 (TLS, /health, /info,
  /attestation), routes every challenge to enclaved over the Unix socket.
  Client: `bootproof verify <ip> --direct --trust` (host release build in
  `~/Sources/bootproof`, pin `7a448f4`).
- **sshdt** — `--no-config --port 22 --bind 0.0.0.0 --host-key
  /run/ssh/host_ed25519 --authorized-keys /root/.ssh/authorized_keys`;
  `when`-gate on the authorized-keys file (fail-closed anonymous auth).
- **userdata** — enclaved reads IMDS 169.254.169.254 (AWS) with config-drive
  ISO fallback (QEMU). Writes `/run/userdata`, `/etc/hostname`,
  `/root/.ssh/authorized_keys`; the unprivileged user is read from
  `/run/userdata`.
- **LUKS /home** — pure-Rust open path via enclaved (no cryptsetup in the open
  path; `cryptsetup luksFormat` stays the first-boot format oracle). Two-stage
  PCR handles: `0x81010200` (seed, pcrs 5,7) → `0x81010201` (full, pcrs
  4,5,7,9), migrated in-process. `/home` = ext4 on `/dev/mapper/home`,
  `LABEL=stagex-home`; without a data disk `/home` stays tmpfs.

## Scripts

| script | purpose |
|---|---|
| `src/verify-execd-common.sh` | shared capture (PCRs + page-aligned event-log + UKI-from-ESP + fresh 64-byte SNP nonce + snpguest report); sourced by both AWS legs |
| `src/verify-uki-execd.sh <ip>` | pre-Phase-4 entry point, unchanged contract: capture + `verify-binding --uki --no-part` |
| `src/verify-execd-stack.sh <ip> [port]` | QEMU/any-host stack verifier (zero-shell, socket, face, LUKS, dmesg, userdata) |
| `src/verify-execd-aws.sh <ip>` | AWS leg: capture + BOUND + stack + full-policy handles |

The old slow event-log dump (`dd bs=1 ... | base64`, ~25 min over ssh) is
superseded by the page-aligned form: `dd if=/dev/mem bs=4096
skip=$((TPMEventLog_addr/4096 - 8192)) count=8192` (a 32 MiB window before
the log). ~1 s.

## QEMU

```sh
# fresh TPM + no data disk
docker rm -f qemu-dev
make qemu-start

# blank 1 GiB data disk (-> /dev/vdb), LUKS matrix
dd if=/dev/zero of=out/home.img bs=1M count=1024
make qemu-start QEMU_DATA_DISK=$PWD/out/home.img
# reboot (swtpm state persists in the container's /tmp/tpm)
docker restart qemu-dev
# truly fresh TPM (handles gone)
docker rm -f qemu-dev && make qemu-start
```

- SSH: `ssh -i ~/.ssh/tpm-exploration.pem -p 2222 root@localhost`
- serial: `docker logs qemu-dev`
- QEMU has no `/dev/sev-guest`: `memory_encryption NOT PROVEN` with a reason is
  the CORRECT honest state — do not fail on it.
- The harness forwards guest `:443` -> host `:443` (bootproofd face) alongside
  `:2222` -> `:22` (the QEMU netdev hostfwd list), so the client can reach
  `https://localhost/health` + `/attestation` directly.
- **Pin rotation on QEMU:** bootproofd's identity is generated under the LUKS
  /home (or /root tmpfs), so it ROTATES whenever that storage is recreated.
  The client's `--pin` treats a changed SPKI as drift (hard fail) — correct
  for real targets, but the stack verifier clears the localhost pin first and
  re-pins (TOFU). AWS identities live on the persistent EBS volume and keep
  their pins; a drift there is a real signal.
- QEMU's `snpguest` produces a zeroed dummy report; `verify-binding`
  auto-skips the nonce echo there (the AWS leg is where the nonce proof is
  load-bearing).

Verify (QEMU):

```sh
bash src/verify-execd-stack.sh localhost 2222
```

## The 3-boot LUKS matrix (data disk attached)

The "expected" log strings are the legacy `home.sh` phrasing — enclaved may
word them differently; the load-bearing facts are the `handles-persistent`
state and the `/home` mount.

| boot | command | expected |
|---|---|---|
| 1 (blank disk) | `make qemu-start QEMU_DATA_DISK=$PWD/out/home.img` | `home: ok (formatted /dev/vdb, seed pcrs 5,7; full pcrs 4,5,7,9 apply next boot)` — ext4 on /home, ONLY `0x81010200` in `handles-persistent` |
| 2 (seed → full) | `docker restart qemu-dev` | `home: ok (luks /dev/vdb, seed pcrs 5,7, migrated to pcrs 4,5,7,9)` — BOTH handles, ext4 on /home (this is the previously-broken case under brush's fake `wait`) |
| 3 (steady full) | `docker restart qemu-dev` | `home: ok (luks /dev/vdb, pcrs 4,5,7,9)` — full-branch steady, no re-migrate, ext4 on /home |

Fail-closed check (optional): evict both handles → reboot →
`home: locked (TPM unseal failed; /home stays tmpfs)`, root SSH still works,
no `/dev/mapper/home`.

Without a data disk, every boot: `/home` on tmpfs — the correct fail-soft
state (the stack verifier accepts both branches).

## AWS

```sh
# creds: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY from [default]
export AWS_ACCESS_KEY_ID=$(awk -F= '/access_key_id/{print $2}' ~/.aws/credentials)
export AWS_SECRET_ACCESS_KEY=$(awk -F= '/secret_access_key/{print $2}' ~/.aws/credentials)
# build + import + deploy (one import; the import is a file target on
# out/aws-ami.tfvars and re-runs only when out/disk.img changes)
make deploy-ec2 EC2_DATA_VOLUME_SIZE=10
# re-fetch the public IP (it CHANGES after any stop/start)
aws ec2 describe-instances --filters Name=instance-state-value,Values=running \
  --query 'Reservations[].Instances[].{id:InstanceId,ip:PublicIpAddress}' \
  --region us-east-2
```

- `EC2_DATA_VOLUME_SIZE=10` = 10 GB data volume for the LUKS /home.
- First boot: seed handle only (5,7) → **reboot once** (or stop/start) →
  migration to full (4,5,7,9) → steady. The `handles` section of
  `verify-execd-aws.sh` requires BOTH handles, so run it after the migration
  boot.
- After any `stop-instances`/`start-instances`, re-fetch the IP before
  probing — the old IP is dead.
- SEV-SNP instances have encrypted console output; if one sits `running` with
  no SSH, `stop`→`start` (host migration) is the remedy.

Verify (AWS):

```sh
bash src/verify-execd-aws.sh <public-ip>
```

## Pass criteria

**Stack verifier (`verify-execd-stack.sh`)** — every section must print a
PASS line:

1. **ssh** — ssh reachable on `<ip>:<port>`.
2. **zero-shell** — `ps -eo pid,comm,args` shows NO sh/ash/brush/dash and NO
   `*.sh` process; PID 1 comm = `execd` (nit → execd line); comm set
   contains `{execd, enclaved, sshdt, bootproofd, dhcp-client}` (getty absent
   is expected, lo already exited as a oneshot); `enclaved` is exactly ONE
   process (no-restart); `sshdt` + `bootproofd` present.
3. **socket** — `/run/enclaved/sock` exists, mode 600, inside `/run/enclaved`
   mode 700; `/run/enclaved/ready` exists.
4. **face** — `bootproof verify <ip> --direct --trust`: `tpm_quote` PROVEN
   and `pcr_state` PROVEN; `memory_encryption` PROVEN only on SNP hosts
   (NOT PROVEN with a reason on QEMU swtpm is correct and does NOT fail).
5. **luks** — data disk attached: `/home` is ext4 on `/dev/mapper/home` with
   LUKS2 `LABEL=stagex-home` on the backing whole disk (blkid; the ext4 LABEL on /dev/mapper/home is `home`); no data disk: `/home` on
   tmpfs is the correct state.
6. **dmesg** — zero lines matching `traps|general protection|CFI|UBSAN|BUG`
   (the "report a bug" boilerplate line excluded).
7. **userdata** — `/etc/hostname` non-empty; `/root/.ssh/authorized_keys`
   non-empty.

**AWS leg (`verify-execd-aws.sh`)** — the stack criteria plus:

8. **bound** — `verify-binding --uki --no-part` → `VERDICT: BOUND`: UKI
   section name+data digests all MATCH the event log; PCR 0/1/2/3/6/7/9
   replay==live (PCR7 = `65CAF8DD1E0EA7A6…`); PCR9 `LOADED_IMAGE::LoadOptions`
   + `Linux initrd` predicted MATCH; PCR11 no-partition (ESP-only disk); SNP
   v5 report echoes the fresh 64-byte nonce (freshness).
9. **handles** — `tpm2_getcap handles-persistent` shows BOTH `0x81010200`
   (seed, pcrs 5,7) and `0x81010201` (full, pcrs 4,5,7,9).

Both scripts exit 0 with a final PASS line, nonzero with the failing section
named.

## Gotchas

- **NitroTPM persistent handles survive guest reboot** — they persist across
  `reboot-instances`; the two-stage migration is per-volume, not per-boot.
- **NitroTPM transient-pool wedge** (`0x0902` with empty `handles-transient`,
  `tpm2_createprimary` failing identically): NO userspace recovery;
  `stop`→`start` gives a fresh Nitro card (NV persistent handles restored, no
  data loss, new IP).
- **`/root` is a nit tmpfs mount — wiped on every boot.** Any helper binary
  must be re-transferred each boot (`cat f | ssh … 'cat > /root/f && chmod 755
  /root/f'`; scp fails, no sftp-server).
- **busybox `ls -d A B` prints nothing if B is missing** (unlike GNU) — test
  paths individually.
- **`stat -f` for truth, not `df`** (busybox df reports the bottom of
  stacked mounts: the tmpfs under the LUKS ext4 at /home).
- The host `bootproof` release build links tss2 + libunwind dynamically;
  `LD_LIBRARY_PATH=$HOME/pip-live/usr/lib` makes it run on this host.

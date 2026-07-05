# kube-etcd-switch — AGENTS.md

> **Revived Jul 2026.** etcd `3.6.13`, cfssl `1.4.1`, K8s `1.36.2`, containerd `2.2.5`, Calico CNI on single node (`vm` 10.160.0.7).
> Scripts assume `kubeadm` static-pod etcd and `sudo systemctl restart containerd` for
> runtime restart.

## Execution model

- **All operations run via SSH** from this admin machine.
- `remote_cmd`, `remote_script`, `remote_copy` wrap `ssh`/`scp` in `utils.sh:106-121`.
- **SSH key access** to all nodes is a prerequisite (`help/ssh-*.txt`).
- Scripts are **sourced** (`. script.sh`), never executed as subprocesses, to share
  variables/functions. The sole exception: `cluster.sh` runs as `./cluster.sh`.
- `read_setup()` auto-runs when `utils.sh` is sourced (line 96: `"read_setup"`).
- `$debug` env var enables verbose output (`export debug=1`).

## Key commands

| Action | Command |
|---|---|
| Menu UI | `./cluster.sh` |
| Cluster state | `. checks/cluster-state.sh` (sets `$cluster_state`) |
| Gen certs one node | `. gen-cert.sh <hostname> <ip>` |
| Gen certs all | `. gen-certs.sh` |
| Snapshot save | `. save-snapshot.sh <name> <embedded\|external>` |
| Snapshot restore → embedded | `. restore-snapshot@masters.sh <snapshot-file>` |
| Snapshot restore → external | `. restore-snapshot@ext-etcd-nodes.sh <snapshot-file>` |
| Admit node | `admit_etcd_cluster_node <hostname> <ip> external` (utils fn) |
| Remove node | `remove_admitted_node <ip> external` (utils fn) |
| System init | `. system-init.sh <master-ip>` |
| Full cycle test (sourced) | `. tests/full-cycle-test.sh` (start from `external-up`) |

## Config (`setup.conf`)

- `etcd_servers` — `hostname:ip hostname:ip ...` for external etcd nodes
- `masters` — `hostname:ip hostname:ip ...` for kube control-plane nodes
- `etcd_version` — etcd binary version to install (default `3.6.13`)
- `read_setup()` parses into `$master_ips`, `$master_names`, `$master_address`
  (first master IP), `$etcd_ips`, `$etcd_names`
- After editing `setup.conf`, call `read_setup` or source any script that sources `utils.sh`

## Paths

| Path | Purpose |
|---|---|
| `/etc/backup/` | Snapshot `.db` files |
| `$HOME/.kube_vault/` | State archives, paused manifests |
| `$HOME/.kube_vault/migration-archive/` | Saved cluster state `tar.gz` |
| `/etc/kubernetes/pki/etcd/` | CA + node certs |
| `generated/` | Temp certs, systemd configs (gitignored, ephemeral) |

## Certs (cfssl quirk)

- Profiles (`client`, `server`, `peer`) live in **`ca-csr.json`**, not `ca-config.json`.
  Scripts pass `-config=ca-csr.json` to `cfssl gencert` — unconventionally named but
  functional. `ca-config.json` exists but is **unused**.
- Template: `csr-template.json` with `#etcd-host#` placeholder.
- `gen-cert.sh` does **not** pass SANs to the client profile; `gen-certs.sh` does for all
  three. Both work because etcd client connections rarely enforce SANs.
- cfssl outputs `.pem`; scripts rename to `.crt` / `.key` (`gen-cert.sh:42-43`).
- `install-cfssl.sh` pins cfssl v1.4.1.

## Systemd template

`etcd-systemd-config.template` → `sed`-replaced into `{gendir}/{ip}-etcd.service`:
- `#etcd-host#`, `#etcd-ip#`, `#data-dir#`, `#initial-cluster-token#`, `#initial-cluster#`
- Fresh clusters: `gen-systemd-configs.sh` uses `gen_token()` → `generated/.token` for
  consistent cluster tokens across all nodes.
- Member additions: `gen_systemd_config()` in `utils.sh:1003` pins `state=existing`.

## Dependencies

- `fping` (auto-installed by `system-init.sh`)
- `cfssl` / `cfssljson` v1.4.1 (`install-cfssl.sh`)
- `etcdctl`/`etcdutl`/`etcd` at `/usr/local/bin/` (`install-etcd.script`)
- `etcd_cmd()` (`utils.sh:708`) wraps `etcdctl --cacert=... --cert=... --key=...`
- `install-etcd.script` reads version from `setup.conf` and installs all three binaries

## Known fixups applied

| File | Change |
|---|---|
| `install-etcd.script` | Reads `etcd_version` from `setup.conf`; installs `etcdutl`; version-aware guard |
| `copy-certs.sh` | scp → `/tmp` + `sudo mv` to `/etc/kubernetes/pki/etcd/` |
| `copy-systemd-config.sh` | scp → `/tmp` + `sudo mv` to `/etc/systemd/system/` |
| `copy-snapshot.sh` | `sudo mkdir -p` + scp → `/tmp` + `sudo mv` |
| `resume-embedded-etcd.sh` | `sudo mv` for both local and remote |
| `stop-etcd.script` | `sudo` for `systemctl` |
| `unarchive.script` | `sudo tar` (root-owned target paths) |
| `synch-etcd-endpoints.sh` | `sudo cat` + scp → `/tmp` + `sudo mv` |
| `archive.script` | `sudo cp` + `sudo chown` for root-owned manifests |
| `suspend-embedded-etcd.sh` | `sudo mv` on remote |
| `utils.sh` (`sync_etcd_endpoints`) | `sudo cat` + `sudo mv` |
| `utils.sh` (`copy_systemd_config`) | scp → `/tmp` + `sudo mv` |
| `utils.sh` (`sync_etcd_endpoints_to_embedded`) | New function for reverse switch |
| `utils.sh` + all etcdctl calls | Removed `ETCDCTL_API=3` (unrecognized in 3.6) |
| All `etcdctl snapshot status/restore` | → `etcdutl snapshot status/restore` |

## Notes

- Pure bash — no build, lint, typecheck, or formatter.
- No automated test framework; `tests/destructive-script.sh` wipes all kube resources.
- `cluster-state.sh` exports `$cluster_state` ∈ `{embedded-up, external-up, emdown, ukdown}`.
  - `embedded-up` = cluster up + API server points to `127.0.0.1:2379`
  - `external-up` = cluster up + API server points to external endpoint
  - `emdown` = cluster down + config points to embedded
  - `ukdown` = cluster down + config points to external
- `console.sh` drops into interactive bash with `utils.sh` loaded.
- No single "switch" command — the migration is an explicit multi-step sequence.
- **Full cycle test** at `tests/full-cycle-test.sh` — start from `external-up` state.
  - Uses `check_or_fail()` helper with `|| return 1` to stop on failure.
  - Cluster-state polling loops up to ~45s before declaring failure.
- `stop-external-etcds.sh` stops + disables the systemd service but leaves the unit file.
- `#ETCD_VER#` removed from `install-etcd.script` — reads version directly from `setup.conf`.
- `system-init.sh`: removed stale `sed` for `#ETCD_VER#` (install-etcd.script is now self-contained).
- `tests/full-cycle-test.sh`: added `check_or_fail()` guard (stops on mismatch via `|| return 1`),
  cluster-state wait loops (up to 45s polling every 3s) to avoid premature read.

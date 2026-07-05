# kube-etcd-switch

> **Zero-downtime migration between embedded (static-pod) and external (systemd) etcd
> for kubeadm Kubernetes — reversible, scriptable, and fully agentless.**

---

## Why this exists

A standard `kubeadm init` runs etcd as a static pod inside the control-plane. That's
fine for test clusters, but in production the **shared-fate coupling** between etcd
and the API server creates real pain:

| Problem | Reality |
|---|---|
| **Resource contention** | etcd is fsync-sensitive and latency-critical. The API server, scheduler, and controller-manager compete for the same CPU/memory/disk on the master. |
| **Coupled lifecycle** | You cannot upgrade, scale, or tune etcd independently. An etcd bump requires draining every master. |
| **No failure isolation** | A master node failure takes down both the API server and its local etcd member. On 3 masters you lose 1/3 of quorum instantly. |
| **Rigid topology** | etcd members cannot outnumber master nodes. You cannot spread the data plane across different racks, AZs, or dedicated hardware. |

**External etcd fixes all of this.** Dedicated etcd nodes eliminate resource
contention, allow independent upgrades and scaling, and decouple the data plane
from the control plane so a master failure no longer threatens quorum.

**This project makes the migration safe, repeatable, and reversible.** You are
never locked in — switching back to embedded etcd is a first-class operation.

### What makes this project different

- **No cluster rebuild.** You keep your existing kubeadm cluster. No `kubeadm reset`,
  no re-init, no re-joining nodes.
- **Fully reversible.** Switch embedded → external, then external → embedded.
  Round-trip tested and verified.
- **Snapshot-driven.** Your data moves via `etcdutl snapshot save/restore`, not
  streaming or replication. Every switch starts from a known-good snapshot.
- **State archives as safety net.** Before any operation you can save full cluster
  state (manifests + systemd configs from every node) and restore with one command.
- **Agentless.** All operations run via SSH from a single admin machine. Nothing is
  installed on the cluster nodes beyond `etcd` and standard SSH.
- **Menu-driven + scriptable.** The `cluster.sh` interactive menu covers every
  operation, and every individual script can be sourced directly for automation.
- **Pure bash.** No Python, no Ruby, no Node, no containers. One dependency:
  `cfssl` for certificates (auto-installed by `system-init.sh`).

---

## Architecture

```
                 ┌─────────────────────────────-┐
                 │     kube-apiserver.yaml      │
                 │  --etcd-servers=<url>        │
                 └──────────┬───────────────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
   ┌─────────────────────┐   ┌──────────────────────────┐
   │  Embedded etcd      │   │  External etcd           │
   │  (kubeadm static    │   │  (systemd on dedicated   │
   │   pod)              │   │   or shared nodes)       │
   │  port 2379          │   │  port 2379, 2380         │
   └─────────────────────┘   └──────────────────────────┘
         ▲                            ▲
         │                            │
         └──────────┬─────────────────┘
                    │
         ┌──────────┴──────────┐
         │   setup.conf        │
         │   etcd_servers=     │
         │   masters=          │
         │   etcd_version=     │
         └─────────────────────┘

         Admin machine (this repo)
         ┌──────────────────────┐
         │  SSH → all nodes     │
         │  kubectl → master    │
         │  cfssl, etcdctl      │
         └──────────────────────┘
```

All operations are driven from **one admin machine** (where this repo is cloned).
Remote nodes are reached exclusively via SSH. No agent, no sidecar, no daemon set.

### Cluster states

The system tracks four states via `checks/cluster-state.sh`:

| State | `kubectl cluster-info` | `kube-apiserver.yaml` points to | Meaning |
|---|---|---|---|
| `embedded-up` | ✅ success | `https://127.0.0.1:2379` | Cluster running on embedded etcd |
| `external-up` | ✅ success | `https://<ext-ip>:2379` | Cluster running on external etcd |
| `emdown` | ❌ failure | `https://127.0.0.1:2379` | Configured for embedded but cluster down |
| `ukdown` | ❌ failure | external URL or unknown | Cluster down, no embedded config |

---

## Prerequisites

<details>
<summary><b>Minimum requirements</b></summary>

- **One admin machine** (can be any Linux box with SSH access) — this is where
  you clone the repo and run all commands.
- **One or more Kubernetes control-plane nodes** provisioned with `kubeadm`.
  The cluster must be running and reachable from the admin machine.
- **One or more dedicated machines for external etcd** — these can be the
  master nodes themselves (single-node or multi-node) or separate VMs/bare
  metal. They need SSH access from the admin machine.
- **SSH key-based authentication** to all nodes (masters and etcd servers).
  See `help/ssh-setup.txt` and `help/copy-ssh-key.txt` for setup.
- **Passwordless sudo** on all remote nodes (scripts use `sudo` for root-owned
  paths like `/etc/kubernetes/manifests/` and `/etc/systemd/system/`).
</details>

<details>
<summary><b>Software dependencies (auto-installed)</b></summary>

The `system-init.sh` script installs these on the admin machine automatically:

- `bash` 4.x+
- `ssh` / `scp`
- `fping` — fast ICMP probing
- `cfssl` / `cfssljson` v1.4.1 — certificate generation
- `etcdctl` / `etcdutl` / `etcd` — etcd client and utility
- `tree` — display generated file structure
- `wget` — download etcd binaries
- `kubectl` — Kubernetes API access (configured from the master's kubeconfig)

The admin machine must **already have kubectl access** to the cluster (a working
`~/.kube/config` is set up during system-init).
</details>

<details>
<summary><b>Supported platforms</b></summary>

Tested on:
- **Kubernetes**: kubeadm 1.36.2 (should work on 1.20+)
- **etcd**: 3.6.13 (embedded + external)
- **OS**: Debian 13 "Trixie", Ubuntu 20.04+
- **Container runtime**: containerd 2.2.5
- **CNI**: Calico

The scripts are pure bash and should work on any Linux distribution with
standard coreutils. YMMV on non-Debian derivatives (apt is used for
dependency installation).
</details>

---

## Quick start

```bash
git clone <this-repo> && cd kube-etcd-switch

# 1. Edit configuration
vim setup.conf
#   etcd_servers=<external-node-hostname>:<ip>
#   masters=<control-plane-hostname>:<ip>
#   etcd_version=3.6.13

# 2. Initialize the admin machine (sources utils.sh)
./cluster.sh → "System init"

# 3. Verify cluster state
. checks/cluster-state.sh
# → "Cluster is running on embedded etcd"

# 4. Deploy external etcd
. setup-etcd-cluster.sh

# 5. Switch to external etcd
#    (generate configs → start external → suspend embedded → sync endpoints)
```

Or run the full cycle test (requires `external-up` or `embedded-up` starting state):

```bash
. tests/full-cycle-test.sh
```

---

## Detailed operations

### Configuration (`setup.conf`)

<details>
<summary><b>Fields and parsing</b></summary>

```ini
etcd_servers=hostname:ip hostname:ip ...
masters=hostname:ip hostname:ip ...
etcd_version=3.6.13
etcd_ca=/etc/kubernetes/pki/etcd/ca.crt
etcd_key=/etc/kubernetes/pki/etcd/ca.key
default_backup_loc=/etc/backup
default_restore_path=/var/lib/etcd-restore
sleep_time=3
kube_install_git_repo=https://github.com/ratulb/k8s-easy-install.git
```

`read_setup()` (in `utils.sh:40`) parses this file and exports:

| Variable | Source |
|---|---|
| `$etcd_servers` | raw value from file |
| `$etcd_ips` | IPs extracted from `etcd_servers` |
| `$etcd_names` | hostnames extracted from `etcd_servers` |
| `$masters` | raw value from file |
| `$master_ips` | IPs extracted from `masters` |
| `$master_names` | hostnames extracted from `masters` |
| `$master_address` | IP of the first master entry |
| `$etcd_version` | etcd binary version |
| `$gendir` | `$(pwd)/generated` |
| `$kube_vault` | `$HOME/.kube_vault` |

After editing `setup.conf`, call `read_setup` or source any script that
sources `utils.sh` (the function runs automatically at line 96).
</details>

### System initialization

<details>
<summary><b><code>system-init.sh</code></b></summary>

This must run once before any other operation. It:

1. Verifies SSH access to the first master
2. Installs `kubectl` configured for the cluster
3. Queries Kubernetes API for all control-plane nodes
4. Installs `fping`, `cfssl`, `cfssljson`, `tree`, `wget`
5. Creates working directories:
   - `~/.kube_vault/` — state archives, paused manifests
   - `~/.kube_vault/migration-archive/` — saved state tarballs
   - `/etc/backup/` — snapshot `.db` files
   - `generated/` — temporary certs and systemd configs (gitignored)
6. Generates the shared etcd CA (`ca.crt` / `ca.key` at `/etc/kubernetes/pki/etcd/`)
7. Generates client, server, and peer certs for the admin machine
8. Installs etcd binary on the admin machine
9. Writes `masters=hostname:ip ...` back to `setup.conf`
</details>

### Certificate generation

<details>
<summary><b>cfssl-based three-tier cert set</b></summary>

Every etcd node needs three certificate pairs:

| Profile | SANs | Used by |
|---|---|---|
| `client` | hostname [+ IP for bulk gen] | etcdctl, API server → etcd |
| `server` | hostname, IP, 127.0.0.1, localhost | etcd's serving TLS |
| `peer` | hostname, IP, 127.0.0.1, localhost | etcd peer-to-peer TLS |

Profiles are defined in **`ca-csr.json`** (NOT `ca-config.json` — the scripts
pass `-config=ca-csr.json` to `cfssl gencert`). `ca-config.json` exists but
is unused.

**Known inconsistency:** `gen-cert.sh` (single node) does NOT pass SANs to the
client profile; `gen-certs.sh` (bulk) passes hostname+IP SANs to all three.
Both work because etcd client connections rarely enforce SAN matching.

Output lands in `generated/`:
```
{hostname}-client.crt / .key
{hostname}-server.crt / .key
{hostname}-peer.crt   / .key
```

cfssl outputs `.pem` files; the scripts rename to `.crt` / `.key`.

**CA files** live at `/etc/kubernetes/pki/etcd/ca.{crt,key}` and are copied
to every node that needs them.
</details>

### Embedded etcd lifecycle

<details>
<summary><b>Suspend and resume</b></summary>

Embedded etcd runs as a static pod via `/etc/kubernetes/manifests/etcd.yaml`.
The kubelet watches this directory and starts/stops pods accordingly.

**Suspend** (`suspend-embedded-etcd.sh <hostname> <ip>`):
- Deletes the etcd static pod via `kubectl -n kube-system delete pod etcd-<hostname>`
- Moves `etcd.yaml` → `$kube_vault/` (out of the manifests directory)
- The kubelet detects the removal and stops the etcd container
- Port 2379 is freed

**Resume** (`resume-embedded-etcd.sh <ip>`):
- Moves `$kube_vault/etcd.yaml` → `/etc/kubernetes/manifests/`
- The kubelet detects the new manifest and starts the etcd static pod
- Port 2379 is claimed by the new etcd process
</details>

### External etcd lifecycle

<details>
<summary><b>Setup, start, stop</b></summary>

**Setup** (`setup-etcd-cluster.sh`):
1. Generates certs for every node in `etcd_servers` (via `gen-certs.sh`)
2. Installs the `etcd` binary on each node (`install-etcd.script`)
3. Copies certs to each node (`copy-certs.sh`)
4. Creates backup and restore directories (`prepare-etcd-dirs.script`)

**Systemd config** (`gen-systemd-configs.sh`):
- Reads `etcd-systemd-config.template` and replaces placeholders via `sed`:
  - `#etcd-host#` → node hostname
  - `#etcd-ip#` → node IP
  - `#data-dir#` → `/var/lib/etcd-restore/restore#N`
  - `#initial-cluster-token#` → generated token from `generated/.token`
  - `#initial-cluster#` → `hostname=https://ip:2380,...`
- Writes to `generated/<ip>-etcd.service`
- For **fresh clusters**: token is generated via `gen_token()` → `generated/.token`
- For **member additions**: `gen_systemd_config()` in `utils.sh:1003` sets
  `state=existing` instead of a token

**Copy** (`copy-systemd-config.sh <ip>`):
- scp → `/tmp/etcd.service` on target → `sudo mv` to `/etc/systemd/system/etcd.service`

**Start** (`start-external-etcds.sh [ips...]`):
- Runs `start-etcd.script` on each node:
  ```bash
  sudo systemctl daemon-reload
  sudo systemctl enable etcd
  sudo systemctl restart etcd
  sudo systemctl status etcd --no-pager
  ```

**Stop** (`stop-external-etcds.sh [ips...]`):
- Runs `stop-etcd.script` on each node:
  ```bash
  sudo systemctl stop etcd
  sudo systemctl disable etcd
  sudo systemctl daemon-reload
  ```
- Stops AND disables the service but **leaves the unit file** in `/etc/systemd/system/`
</details>

### Snapshots

<details>
<summary><b>Save, restore, verify</b></summary>

**Save** (`save-snapshot.sh <name> <embedded|external>`):
1. Detects the target cluster's etcd endpoint (embedded or external)
2. Runs `etcd_cmd snapshot save` to `/etc/backup/<name>-{em|ext}-snapshot#N.db`
3. Prints `etcdutl snapshot status`

**Restore to embedded** (`restore-snapshot@masters.sh <snapshot-file>`):
1. Saves current cluster state (auto-backup)
2. Copies snapshot to each master
3. Runs `etcdutl snapshot restore` with a fresh cluster token
4. Updates each master's `etcd.yaml` data-dir, token, and initial-cluster
5. Waits for embedded cluster to recover

**Restore to external** (`restore-snapshot@ext-etcd-nodes.sh <snapshot-file>`):
1. Saves current cluster state
2. Generates fresh systemd configs for external nodes
3. Copies snapshot to each etcd node
4. Runs `etcdutl snapshot restore` with a new token
5. Stops embedded etcd, starts external, syncs endpoints

**Important:** etcd 3.6 deprecates `etcdctl snapshot status` and
`etcdctl snapshot restore`. All snapshot operations use `etcdutl snapshot`
instead.
</details>

### The switch: embedded ↔ external

<details>
<summary><b>Embedded → External (step by step)</b></summary>

```
1. Save snapshot       save-snapshot.sh <name> embedded
2. Set up external     setup-etcd-cluster.sh
3. Generate configs    gen-systemd-configs.sh
4. Copy configs        copy-systemd-config.sh <ip>        (for each node)
5. Copy snapshot       copy-snapshot.sh <snapshot> <ip>   (for each node)
6. Restore snapshot    restore-snapshot.sh <snap> <dir> <token> <ip> <cluster>
7. Suspend embedded    suspend-embedded-etcd.sh <hostname> <ip>
8. Start external      start-external-etcds.sh <ip>
9. Sync endpoints      sync_etcd_endpoints                (utils function)
```

After step 9, the API server is restarted by kubelet (detecting the manifest
change) and connects to the external etcd cluster.
</details>

<details>
<summary><b>External → Embedded (step by step)</b></summary>

```
1. Stop external        stop-external-etcds.sh <ip>
2. Resume embedded      resume-embedded-etcd.sh <ip>
3. Wait for port 2379   verify ss -tlnp | grep 2379
4. Sync endpoints       sync_etcd_endpoints_to_embedded    (utils function)
5. Wait for API server  kubectl cluster-info
```

After step 4, the API server manifest points back to `https://127.0.0.1:2379`
and the kubelet restarts the API server against the embedded etcd.
</details>

### State management

<details>
<summary><b>Save and restore full cluster state</b></summary>

A **state** is a full-cluster backup: manifests (`etcd.yaml`,
`kube-apiserver.yaml`) and systemd unit files from every node, bundled into a
tar.gz in `~/.kube_vault/migration-archive/`.

**Save** (`save-state.sh <name>`):
- Runs `archive.script` on every accessible node (masters + etcd servers)
- Collects:
  - `/etc/kubernetes/manifests/etcd.yaml` (if present)
  - `/etc/kubernetes/manifests/kube-apiserver.yaml`
  - `/etc/systemd/system/etcd.service` (if present)
- Tarball name: `<cluster_state>#<name>@<timestamp>.tar.gz`

**Restore** (`restore-state.sh <prefix>`):
1. Stops whatever etcd is currently running (embedded or external)
2. Extracts the state archive across all nodes via `unarchive.script`
3. Restarts the appropriate etcd (determined by the `embedded-up#` or
   `external-up#` prefix in the archive name)

This is the **primary recovery mechanism** — as long as a saved state exists,
you can return the cluster to a known-good configuration.
</details>

---

## Reference

### File catalog

<details>
<summary><b>All scripts and their purposes</b></summary>

| File | Purpose |
|---|---|
| `cluster.sh` | Main menu entrypoint |
| `utils.sh` | Shared library — source before everything |
| `setup.conf` | Single configuration file |
| `system-init.sh` | First-time initialization against a master |
| `gen-cert.sh` | Generate cfssl certs for one node |
| `gen-certs.sh` | Generate cfssl certs for all configured nodes |
| `setup-etcd-cluster.sh` | Full external etcd deployment |
| `save-snapshot.sh` | etcd snapshot save |
| `restore-snapshot.sh` | etcd snapshot restore (single node) |
| `restore-snapshot@masters.sh` | Restore snapshot to embedded cluster |
| `restore-snapshot@ext-etcd-nodes.sh` | Restore snapshot to external cluster |
| `save-state.sh` | Cluster-wide state save |
| `restore-state.sh` | Cluster-wide state restore |
| `suspend-embedded-etcd.sh` | Move etcd.yaml out of manifests/ |
| `resume-embedded-etcd.sh` | Move etcd.yaml back to manifests/ |
| `start-external-etcds.sh` | systemctl start on external etcd nodes |
| `stop-external-etcds.sh` | systemctl stop on external etcd nodes |
| `admit-etcd-cluster-node.sh` | Add a node to running etcd cluster |
| `remove-admitted-node.sh` | Remove a node from a running etcd cluster |
| `synch-etcd-endpoints.sh` | Update kube-apiserver etcd-servers on one master |
| `switch-to-etcd-cluster.sh` | Start external etcd + sync endpoints |
| `gen-systemd-configs.sh` | Generate systemd unit files from template |
| `etcd-systemd-config.template` | Systemd unit template |
| `csr-template.json` | CSR template with `#etcd-host#` placeholder |
| `ca-csr.json` | CA signing profiles: client, server, peer |
| `ca-config.json` | CA config (unused — see cert quirk) |
| `install-etcd.script` | Downloads etcd binary to /usr/local/bin |
| `start-etcd.script` | systemctl daemon-reload + enable + restart |
| `stop-etcd.script` | systemctl stop + disable |
| `etcd-restore.script` | Shell-level etcdutl snapshot restore |
| `archive.script` | Collects manifests into tar.gz |
| `unarchive.script` | Extracts manifest tar.gz across nodes |
| `copy-certs.sh` | scp certs from generated/ to target node |
| `copy-snapshot.sh` | scp snapshot file to target node |
| `copy-systemd-config.sh` | scp systemd unit to target node |
| `etcd-cluster-status.sh` | Runs etcd-status.script on each etcd node |
| `external-etcd-status.sh` | systemctl status on each etcd node |
| `install-cfssl.sh` | Installs cfssl and cfssljson |
| `setup-kubectl.sh` | Configures kubectl from master's kubeconfig |
| `restart-runtime.sh` | Restarts docker + kubelet on nodes |
| `prepare-etcd-dirs.script` | Creates backup and restore directories |
| `console.sh` | Interactive bash with utils.sh loaded |
| **checks/** | |
| `checks/cluster-state.sh` | Probe current cluster mode |
| `checks/endpoint-liveness-cluster.sh` | Test external etcd endpoint health |
| `checks/endpoint-liveness.sh` | Test etcd endpoint health (generic) |
| `checks/system-pod-state.sh` | Verify kube-system pod health |
| `checks/ca-cert-existence.sh` | Verify CA exists |
| `checks/system-initialized.sh` | Verify system-init has run |
| `checks/confirm-action.sh` | Interactive confirmation prompt |
| `checks/ssh-access.sh` | Verify SSH to all nodes |
| **widgets/** | |
| `widgets/manage-etcd.sh` | Sub-menu for external etcd management |
| `widgets/system-init.sh` | Sub-menu wrapper for system-init |
| **tests/** | |
| `tests/full-cycle-test.sh` | Embedded → external → embedded round-trip |
| `tests/destructive-script.sh` | Wipes all kube resources (test only!) |
</details>

### SSH and remote execution

<details>
<summary><b>Remote wrappers in utils.sh</b></summary>

All remote operations use three wrappers from `utils.sh:106-121`:

| Function | What it does |
|---|---|
| `remote_cmd <host> <cmd>` | `ssh -q -o StrictHostKeyChecking=no <host> <cmd>` |
| `remote_script <host> <file>` | `ssh -q <host> < <file>` (stdin redirect) |
| `remote_copy <from> <to>` | `scp -q -o StrictHostKeyChecking=no <from> <to>` |

Connection timeout is 3 seconds. Host key checking is disabled.
`sudo -u $usr` is prepended to run as the invoking user.

**Important:** When scripts are piped via `remote_script`, the shebang is
ignored and the remote shell executes the content directly. This means
`readlink -f "$0"` will resolve to `bash` or `-bash`, not the script path.
The project scripts handle this by not relying on `$0` for path resolution.
</details>

### Script execution model

<details>
<summary><b>Source vs. execute</b></summary>

All scripts in this project must be **sourced** (`. script.sh`), never executed
as subprocesses (`./script.sh`). This is because they share variables and
functions from `utils.sh` via the caller's shell. The sole exception is
`cluster.sh` which runs as `./cluster.sh` (it sources `utils.sh` internally).

```bash
# ✅ Correct — inherits shell state
. utils.sh
. suspend-embedded-etcd.sh vm 10.160.0.7

# ❌ Wrong — uses fresh shell, utils.sh functions/vars not available
./suspend-embedded-etcd.sh vm 10.160.0.7
```
</details>

### Certificate quirk

<details>
<summary><b>ca-csr.json vs ca-config.json</b></summary>

Profiles (`client`, `server`, `peer`) live in **`ca-csr.json`**, not
`ca-config.json`. All scripts pass `-config=ca-csr.json` to `cfssl gencert`.

`ca-config.json` exists in the repo but is **completely unused**. This is
unconventional but functional — cfssl accepts the same profile syntax in
either file.

The CSR template (`csr-template.json`) uses `#etcd-host#` as a placeholder
replaced by `sed` before `cfssl gencert` is called.
</details>

### The sudo-mv pattern

<details>
<summary><b>Root-owned paths on remote nodes</b></summary>

Paths like `/etc/kubernetes/manifests/`, `/etc/kubernetes/pki/etcd/`, and
`/etc/systemd/system/` are owned by root. Direct SCP to these paths fails.
The project uses a consistent two-step pattern:

1. SCP to `/tmp/<filename>` (world-writable)
2. `sudo mv /tmp/<filename> <final-path>` (mv as root to the target)

This pattern is used in:
- `copy-certs.sh`
- `copy-systemd-config.sh`
- `copy-snapshot.sh`
- `synch-etcd-endpoints.sh`
- `utils.sh` (`sync_etcd_endpoints`, `sync_etcd_endpoints_to_embedded`,
  `copy_systemd_config`)
- `resume-embedded-etcd.sh` (local and remote)
- `suspend-embedded-etcd.sh` (remote)
</details>

### etcd version

<details>
<summary><b>3.6.x compatibility notes</b></summary>

- etcd 3.6 **deprecates** `ETCDCTL_API=3` — the flag is unrecognized and
  causes errors. All wrapper calls (`etcd_cmd()` in `utils.sh:708`) omit it.
- etcd 3.6 **moves** `snapshot status` and `snapshot restore` to `etcdutl`.
  All snapshot scripts use `etcdutl snapshot` instead of `etcdctl snapshot`.
- The admin machine and external etcd nodes all run the same version (default
  `3.6.13`), configured in `setup.conf`.
- The embedded etcd version is determined by the kubeadm image (e.g., `3.6.8`
  in kubeadm 1.36). The project migrates via snapshot restore, so the version
  mismatch is not a problem — the snapshot is portable.
</details>

### Full cycle test

<details>
<summary><b><code>tests/full-cycle-test.sh</code></b></summary>

This test performs a round-trip: embedded → external → embedded. It can start
from either `embedded-up` or `external-up` state.

```bash
# From project root:
. tests/full-cycle-test.sh
```

**What it does:**

| Phase | From | To | Steps |
|---|---|---|---|
| 0 | any | — | Verify state, clean restore dirs |
| 1* | external-up | embedded-up | Stop external, resume embedded, sync endpoints |
| 2 | embedded-up | external-up | Deploy external, suspend embedded, start external, sync |
| 3 | external-up | embedded-up | Stop external, resume embedded, sync endpoints |

_\*Phase 1 is skipped if starting from `embedded-up`._

**Key implementation details:**
- Uses `check_or_fail()` helper with `|| return 1` to stop on failure
- Cluster-state polling loops up to ~45s (15 attempts × 3s) before declaring
  failure — accounts for kubelet restart delays
- Port 2379 is verified free before starting the opposite etcd mode
- `confirm-action.sh` is never called (blocks on `read` in non-interactive mode)
</details>

### Paths

<details>
<summary><b>Directory layout</b></summary>

| Path | Purpose |
|---|---|
| `/etc/backup/` | Snapshot `.db` files |
| `$HOME/.kube_vault/` | State archives, paused manifests |
| `$HOME/.kube_vault/migration-archive/` | Saved cluster state tar.gz files |
| `/etc/kubernetes/pki/etcd/` | CA + node certs |
| `/etc/kubernetes/manifests/` | kubelet static pod manifests |
| `/var/lib/etcd-restore/` | Snapshot restore data directories |
| `generated/` | Temp certs, systemd configs (gitignored, ephemeral) |
</details>

---

## Troubleshooting

<details>
<summary><b>Diagnostic commands</b></summary>

```bash
# What state is the cluster in?
. checks/cluster-state.sh

# Are etcd endpoints reachable?
. checks/endpoint-liveness-cluster.sh

# Are kube-system pods healthy?
. checks/system-pod-state.sh

# Can we SSH to all nodes?
. checks/ssh-access.sh

# Probe etcd via API server URL
. checks/endpoint-probe.sh

# Enable verbose output
export debug=1
```

`debug=1` enables verbose output showing every SSH command, file transfer,
cert path, and intermediate state lookup via the `debug()` function.
</details>

<details>
<summary><b>Common failures</b></summary>

| Symptom | Likely cause | Fix |
|---|---|---|
| "Can not access address" | SSH key not deployed to the target node | Run steps from `help/copy-ssh-key.txt` |
| "Empty end point list" | `etcd_servers` in `setup.conf` is empty or nodes unreachable | Check `setup.conf`, verify SSH |
| "Has the system been initialized?" | Missing CA at `/etc/kubernetes/pki/etcd/ca.crt` | Run System init from `cluster.sh` menu |
| "Certificate issue" on snapshot | Missing client cert for the target cluster's endpoint | Run `. gen-certs.sh` to regenerate |
| etcd service won't start | Systemd config has stale `#placeholder#` | Check `generated/*.service` — placeholders should be replaced |
| Cluster stuck on "not running" after switch | API server cannot reach the new etcd endpoints | Check firewall rules on etcd port 2379/2380, verify endpoints in `kube-apiserver.yaml` |
| `etcdutl snapshot status` fails | Using `etcdctl` instead of `etcdutl` | Use `etcdutl snapshot status` (etcd 3.6+) |
| Port 2379 still in use after suspend | Embedded etcd container hasn't stopped yet | Wait a few seconds, or check with `sudo ss -tlnp \| grep 2379` |
| `confirm-action.sh` blocks the script | Running non-interactively | The script calls `read` — for automation, avoid scripts that call `confirm-action.sh` |
| "Failed to reset failed state" for systemd unit | Unit was never loaded or was already cleaned up | This is harmless — the unit file still exists, `systemctl start` will load it |
</details>

<details>
<summary><b>Recovery procedures</b></summary>

**From a bad switch (revert to embedded):**

```bash
. stop-external-etcds.sh                  # Stop external etcd if running
. resume-embedded-etcd.sh <master-ip>     # Restore etcd static pod
```

Then restore a saved state if available, or resync endpoints manually:
```bash
sync_etcd_endpoints_to_embedded           # Point API server back to embedded
```

**Full cluster recovery from saved state:**

```bash
. checks/cluster-state.sh                 # Determine current state
. restore-state.sh <saved-state-prefix>    # Full automated recovery
```

The state archive encodes the mode (`embedded-up#...` or `external-up#...`)
and `restore-state.sh` automatically stops the other mode and starts the
correct one.

**When all else fails:** The test cluster can be destroyed and rebuilt:
```bash
source tests/destructive-script.sh        # CAUTION: deletes ALL kube resources
```
</details>

---

## Operational notes

- **There is no single "switch" button.** The project deliberately exposes
  individual steps (deploy certs, start etcd, suspend embedded, sync
  endpoints) so you can verify at every stage.
- **Always take a snapshot before a switch or restore.** The scripts do
  auto-save state during restore operations, but a manual snapshot gives you
  the lightest rollback path.
- **State archives are your safety net.** Save state before any significant
  operation. Restoring a state is the most comprehensive recovery path.
- **The `generated/` directory is ephemeral.** Everything in it can be
  regenerated. It is in `.gitignore`. Certificates are copied to nodes and
  persist there.
- **System init must run before any other operation.** It creates the CA
  and installs `kubectl` — everything else depends on both.
- **External etcd must be started before syncing endpoints.** The API server
  probes its `--etcd-servers` on startup; if external etcd is not ready, the
  API server will fail to come back.
- **Port 2379 is shared.** Embedded and external etcd both listen on port
  2379. They cannot run simultaneously. Always verify port freedom before
  starting the opposite mode.
- **The embedded etcd pod manifest contains your data-dir path.** After a
  snapshot restore, the `etcd.yaml` manifest is updated with the new data-dir
  and cluster token.
- **Scripts assume `kubeadm` static-pod etcd.** If your cluster uses a
  different approach for embedded etcd (e.g., Helm chart), the
  suspend/resume/sync mechanisms need adaptation.
- **For runtime restart:** `sudo systemctl restart containerd` (or docker)
  may be needed after switching modes on the node.

---

## Development

<details>
<summary><b>Building and testing</b></summary>

This project is pure bash — no build system, no linter, no typechecker.
Testing is manual:

```bash
# Full round-trip test
. tests/full-cycle-test.sh

# Quick cluster-state check
. checks/cluster-state.sh

# Console with utils.sh loaded
./console.sh
```

The full cycle test is designed to be run repeatedly and leave the cluster
in a clean `embedded-up` state.
</details>

<details>
<summary><b>Known fixups applied (revived Jul 2026)</b></summary>

This project was revived in July 2026 with significant changes to support
etcd 3.6.x and modern Kubernetes:

| Area | Change |
|---|---|
| `install-etcd.script` | Now reads `etcd_version` from `setup.conf`; installs `etcdutl` alongside `etcd`/`etcdctl`; version-aware reinstall guard |
| All snapshot scripts | Migrated from `etcdctl snapshot status/restore` to `etcdutl snapshot status/restore` (etcd 3.6 deprecation) |
| All etcdctl calls | Removed `ETCDCTL_API=3` (unrecognized in etcd 3.6) |
| `copy-certs.sh`, `copy-systemd-config.sh`, `copy-snapshot.sh` | Added `sudo mv` pattern for root-owned paths on remote nodes |
| `utils.sh` | Added `sync_etcd_endpoints_to_embedded()` function for reverse switch; all remote copies follow `/tmp` → `sudo mv` pattern |
| `tests/full-cycle-test.sh` | Added `check_or_fail()` guard, cluster-state wait loops (up to 45s), support for `embedded-up` and `external-up` starting states |
| `system-init.sh` | Removed stale `#ETCD_VER#` sed line (install-etcd.script is self-contained) |
| `etcd_version` | Bumped from `3.5.31` to `3.6.13` |
</details>

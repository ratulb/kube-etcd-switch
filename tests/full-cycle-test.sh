#!/usr/bin/env bash
# Full cycle test: embedded etcd → external etcd → embedded etcd
# Usage: . tests/full-cycle-test.sh
# Must be sourced from project root (shares shell state with utils.sh)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"
. utils.sh

cleanup() {
  rm -f kube.draft /tmp/install-etcd-vm.tmp /tmp/full-cycle-token.txt /tmp/snapshot-save-msg.txt
}
trap cleanup EXIT

fail() {
  err "TEST FAILED at: $1"
  return 1
}
check_or_fail() {
  if [ "$cluster_state" != "$1" ]; then
    fail "Expected $1, got $cluster_state"
    return 1
  fi
}

pass() {
  prnt "✓ $1"
}

# ============================================================
# Phase 0 — Verify starting state
# ============================================================
prnt "============================================================"
prnt "  PHASE 0: Verify starting state"
prnt "============================================================"

# Clean up old external etcd data dirs from previous runs
remote_cmd 10.160.0.7 "sudo rm -rf /var/lib/etcd-restore/* 2>/dev/null; sudo mkdir -p /var/lib/etcd-restore" || true
rm -f generated/.token generated/*.service
pass "Cleaned restore data dirs"

. checks/cluster-state.sh
if [ "$cluster_state" = "external-up" ]; then
  pass "Starting from $cluster_state — running full cycle (P1→P2→P3)"

  # ============================================================
  # Phase 1 — External → Embedded etcd
  # ============================================================
  prnt "============================================================"
  prnt "  PHASE 1: Switch external etcd → embedded etcd"
  prnt "============================================================"

  prnt "  [1a] Stopping external etcd..."
  . stop-external-etcds.sh 10.160.0.7
  sleep 3
  if remote_cmd 10.160.0.7 "sudo ss -tlnp | grep -q ':2379'" 2>/dev/null; then
    fail "Port 2379 still in use after stopping external etcd"
  fi
  pass "External etcd stopped, port 2379 free"

  prnt "  [1b] Resuming embedded etcd..."
  . resume-embedded-etcd.sh 10.160.0.7
  pass "etcd.yaml moved back to manifests"

  prnt "  [1c] Waiting for embedded etcd..."
  for i in $(seq 1 30); do
    if remote_cmd 10.160.0.7 "sudo ss -tlnp | grep -q ':2379'" 2>/dev/null; then
      pass "Embedded etcd ready (attempt $i)"
      break
    fi
    sleep 2
    if [ "$i" -eq 30 ]; then fail "Embedded etcd failed to start"; fi
  done

  prnt "  [1d] Syncing API server to embedded etcd..."
  sync_etcd_endpoints_to_embedded
  pass "API server manifest → https://127.0.0.1:2379"

  prnt "  [1e] Waiting for API server to settle..."
  for i in $(seq 1 30); do
    if kubectl cluster-info &>/dev/null; then
      pass "API server responding (attempt $i)"
      break
    fi
    sleep 3
    if [ "$i" -eq 30 ]; then fail "API server failed to restart"; fi
  done
  . checks/cluster-state.sh
  for i in $(seq 1 15); do
    if [ "$cluster_state" = "embedded-up" ]; then break; fi
    sleep 3
    . checks/cluster-state.sh
  done
  check_or_fail "embedded-up" || return 1
  pass "Phase 1 complete: cluster_state = $cluster_state"

  prnt "  [1f] Saving embedded snapshot..."
elif [ "$cluster_state" = "embedded-up" ]; then
  pass "Starting from $cluster_state — skipping Phase 1, running Phase 2→3"
  prnt "  [skip] Saving embedded snapshot from current state..."
else
  fail "Expected external-up or embedded-up, got $cluster_state"
fi
next_snapshot cycle-test-em
ETCD_SNAPSHOT=$NEXT_SNAPSHOT
mkdir -p "${ETCD_SNAPSHOT%/*}"
etcd_cmd --endpoints=https://10.160.0.7:2379 snapshot save "$ETCD_SNAPSHOT" &>/tmp/snapshot-save-msg.txt
etcdutl snapshot status "$ETCD_SNAPSHOT" --write-out=table
pass "Snapshot saved: $(basename "$ETCD_SNAPSHOT")"

# ============================================================
# Phase 2 — Embedded → External etcd
# ============================================================
prnt "============================================================"
prnt "  PHASE 2: Switch embedded etcd → external etcd"
prnt "============================================================"

prnt "  [2a] Setting up external etcd cluster..."
rm -f generated/.token generated/*.service
. setup-etcd-cluster.sh 2>&1 | grep -v "^Linux\|^The programs\|^Debian\|^WARNING\|^Get:\|^Hit:\|^Fetched\|^Reading\|^Building\|^Summary:\|^Upgrading:\|^0 upgraded" || true
pass "Certs, binaries, dirs ready"

prnt "  [2b] Generating systemd config..."
rm -f generated/.token generated/*.service
. gen-systemd-configs.sh
pass "Systemd config generated"

prnt "  [2c] Copying systemd config to vm..."
. copy-systemd-config.sh 10.160.0.7
pass "Systemd config copied"

prnt "  [2d] Copying snapshot to vm..."
. copy-snapshot.sh "$ETCD_SNAPSHOT" "10.160.0.7"
pass "Snapshot copied to vm"

prnt "  [2e] Restoring snapshot to external etcd data dir..."
ext_etcd_endpoints
gen_token token
echo "$token" >/tmp/full-cycle-token.txt
next_data_dir 10.160.0.7
RESTORE_PATH=$NEXT_DATA_DIR
remote_cmd 10.160.0.7 "sudo mkdir -p $(dirname "$RESTORE_PATH")"
. restore-snapshot.sh "$ETCD_SNAPSHOT" "$RESTORE_PATH" "$token" "10.160.0.7" "$ETCD_INITIAL_CLUSTER"
pass "Snapshot restored to $RESTORE_PATH"

prnt "  [2f] Suspending embedded etcd..."
. suspend-embedded-etcd.sh vm 10.160.0.7
for i in $(seq 1 30); do
  if ! remote_cmd 10.160.0.7 "sudo ss -tlnp | grep -q ':2379'" 2>/dev/null; then
    pass "Embedded etcd stopped (attempt $i)"
    break
  fi
  sleep 2
  if [ "$i" -eq 30 ]; then fail "Embedded etcd still holding port 2379"; fi
done

prnt "  [2g] Starting external etcd..."
remote_cmd 10.160.0.7 "sudo systemctl reset-failed etcd 2>&1; sudo systemctl start etcd 2>&1"
for i in $(seq 1 30); do
  if remote_cmd 10.160.0.7 "sudo ss -tlnp | grep -q ':2379'" 2>/dev/null; then
    pass "External etcd ready (attempt $i)"
    break
  fi
  sleep 2
  if [ "$i" -eq 30 ]; then fail "External etcd failed to start"; fi
done

prnt "  [2h] Syncing API server to external etcd..."
sync_etcd_endpoints
pass "API server manifest → external etcd"

prnt "  [2i] Waiting for API server..."
for i in $(seq 1 30); do
  if kubectl cluster-info &>/dev/null; then
    pass "API server responding (attempt $i)"
    break
  fi
  sleep 3
  if [ "$i" -eq 30 ]; then fail "API server failed to restart"; fi
done

. checks/cluster-state.sh
for i in $(seq 1 15); do
  if [ "$cluster_state" = "external-up" ]; then break; fi
  sleep 3
  . checks/cluster-state.sh
done
check_or_fail "external-up" || return 1
pass "Phase 2 complete: cluster_state = $cluster_state"

# ============================================================
# Phase 3 — External → Embedded etcd (round-trip)
# ============================================================
prnt "============================================================"
prnt "  PHASE 3: Switch external etcd → embedded etcd (round-trip)"
prnt "============================================================"

prnt "  [3a] Stopping external etcd..."
. stop-external-etcds.sh 10.160.0.7
sleep 5
if remote_cmd 10.160.0.7 "sudo ss -tlnp | grep -q ':2379'" 2>/dev/null; then
  fail "Port 2379 still in use after stopping external etcd"
fi
pass "External etcd stopped"

prnt "  [3b] Resuming embedded etcd..."
. resume-embedded-etcd.sh 10.160.0.7
for i in $(seq 1 30); do
  if remote_cmd 10.160.0.7 "sudo ss -tlnp | grep -q ':2379'" 2>/dev/null; then
    pass "Embedded etcd ready (attempt $i)"
    break
  fi
  sleep 2
  if [ "$i" -eq 30 ]; then fail "Embedded etcd failed to start"; fi
done

prnt "  [3c] Syncing API server to embedded etcd..."
sync_etcd_endpoints_to_embedded
pass "API server manifest → https://127.0.0.1:2379"

prnt "  [3d] Waiting for API server..."
for i in $(seq 1 30); do
  if kubectl cluster-info &>/dev/null; then
    pass "API server responding (attempt $i)"
    break
  fi
  sleep 3
  if [ "$i" -eq 30 ]; then fail "API server failed to restart"; fi
done

. checks/cluster-state.sh
for i in $(seq 1 15); do
  if [ "$cluster_state" = "embedded-up" ]; then break; fi
  sleep 3
  . checks/cluster-state.sh
done
check_or_fail "embedded-up" || return 1

prnt ""
prnt "============================================================"
prnt "  FULL CYCLE TEST PASSED"
prnt "  embedded → external → embedded — all phases successful"
prnt "============================================================"

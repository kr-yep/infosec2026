#!/bin/bash
# One-time qualification lab, executed only in the isolated course guest.
set -euo pipefail
test "$(cat /sys/class/dmi/id/product_name)" = VirtualBox
D=/root/infosec-ssh-lab
test ! -e "$D/original.conf"
umask 077
mkdir -p "$D/public"
P=$D/public
finish() {
  r=$?
  trap - EXIT
  for f in "$P"/*.txt; do
    test -f "$f" || continue
    echo "===BEGIN:$(basename "$f")==="
    cat "$f"
    echo
    echo "===END:$(basename "$f")==="
  done
  echo "LAB_EXIT_CODE=$r"
  exit "$r"
}
trap finish EXIT
capture() {
  local dest=$1; shift
  local code=0
  "$@" > "$P/$dest.txt" 2>&1 || code=$?
  echo "$dest=$code" >> "$P/exit-codes.txt"
  return "$code"
}
cp -p /etc/ssh/sshd_config "$D/original.conf"
if grep -Eq '^[[:space:]]*Match[[:space:]]' "$D/original.conf"; then
  echo 'Match blocks require a separately reviewed edit.' >&2; exit 4
fi
{ date -Is; cat /etc/redhat-release; ssh -V 2>&1; rpm -q openssh-server nmap; ip -4 -o addr; } > "$P/environment.txt"
for q in cipher mac kex key; do capture "supported-$q" ssh -Q "$q"; done
capture before-effective /usr/sbin/sshd -T
capture before-service nmap -sV 127.0.0.1
capture before-algorithms nmap -Pn -p22 --script ssh2-enum-algos 127.0.0.1
for k in curve25519-sha256 curve25519-sha256@libssh.org; do
  if capture "check-$k" /usr/sbin/sshd -t -f "$D/original.conf" -o "KexAlgorithms=$k"; then :; fi
done
grep -vE '^[[:space:]]*(Ciphers|MACs|KexAlgorithms)[[:space:]]' "$D/original.conf" > "$D/candidate.conf"
cat >> "$D/candidate.conf" <<'POLICY'

# Isolated course lab policy: supported AES, SHA-2 MACs and SHA-256/ECDH KEX.
Ciphers aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512
KexAlgorithms ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256
POLICY
capture candidate-syntax /usr/sbin/sshd -t -f "$D/candidate.conf"
install -o root -g root -m 600 "$D/candidate.conf" /etc/ssh/sshd_config
restorecon /etc/ssh/sshd_config
systemctl restart sshd
systemctl is-active sshd > "$P/service-state.txt"
capture after-effective /usr/sbin/sshd -T
capture after-algorithms nmap -Pn -p22 --script ssh2-enum-algos 127.0.0.1
grep -E '^(Ciphers|MACs|KexAlgorithms) ' /etc/ssh/sshd_config > "$P/applied-policy.txt"
grep -q 'ssh2-enum-algos:' "$P/after-algorithms.txt"
if grep -Eq 'arcfour|3des|aes[0-9]+-cbc|hmac-md5|hmac-sha1-96|diffie-hellman-group1-sha1|diffie-hellman-group14-sha1|diffie-hellman-group-exchange-sha1' "$P/after-algorithms.txt"; then
  echo 'An excluded algorithm is still advertised.' >&2; exit 5
fi
ssh_args=(-vv -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5)
if capture strong-handshake ssh "${ssh_args[@]}" -c aes128-ctr -m hmac-sha2-256 root@127.0.0.1 true; then :; fi
grep -q 'SSH2_MSG_NEWKEYS received' "$P/strong-handshake.txt"
if capture reject-cbc ssh "${ssh_args[@]}" -c aes128-cbc root@127.0.0.1 true; then exit 6; fi
grep -Eiq 'no matching cipher' "$P/reject-cbc.txt"
if capture reject-md5 ssh "${ssh_args[@]}" -c aes128-ctr -m hmac-md5 root@127.0.0.1 true; then exit 7; fi
grep -Eiq 'no matching mac' "$P/reject-md5.txt"
if capture reject-group1 ssh "${ssh_args[@]}" -o KexAlgorithms=diffie-hellman-group1-sha1 root@127.0.0.1 true; then exit 8; fi
grep -Eiq 'no matching.*(key exchange|kex)|no kex alg|Unable to negotiate a key exchange' "$P/reject-group1.txt"
journalctl -u sshd -n 18 --no-pager > "$P/service-log.txt"
sha256sum /etc/ssh/sshd_config "$0" > "$P/guest-hashes.txt"
echo 'PASS: syntax, active sshd, algorithm advertisement, strong transport handshake, and 3 excluded-algorithm rejections.' > "$P/acceptance.txt"

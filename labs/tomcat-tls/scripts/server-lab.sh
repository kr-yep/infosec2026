#!/usr/bin/env bash
# server-lab.sh - Tomcat 7 TLS Lab Automation Script
# Target: CentOS / RHEL 7 minimal OVA with Tomcat 7, OpenSSL 1.0.2, Java 8, curl 7.29, nmap
# Scope: Isolated guest VM execution only (root caller). No host execution.
# Fail-safe: No network mutation, no package installations, no credential leakage.

set -eEuo pipefail
trap 'echo "[FATAL] Failed at script line ${LINENO}" >&2' ERR
if ! grep -qi VirtualBox /sys/class/dmi/id/product_name 2>/dev/null; then
    echo 'Refusing execution outside the VirtualBox guest' >&2; exit 1
fi
run_capture_rc() {
    local target="$1"; shift
    local rc=0
    "$@" || rc=$?
    printf -v "$target" '%d' "$rc"
}

WORK_DIR="/root/infosec-tomcat-lab"
PUBLIC_DIR="${WORK_DIR}/public"
INIT_FLAG="${WORK_DIR}/.initialized"
PASS_FILE="${WORK_DIR}/keystore.pass"
BACKUP_XML="${WORK_DIR}/server.xml.orig"
SYSTEM_XML="/etc/tomcat/server.xml"
JKS_DEST="/etc/tomcat/keystore.jks"

SERVER_IP="10.20.30.10"
SERVER_DNS="Tomcat-SSL"

# 1. Root caller assertion
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This script must be run as root inside the target VM." >&2
    exit 1
fi

# 2. Date year assertion (must be >= 2026)
CURRENT_YEAR=$(date +%Y)
if [ "${CURRENT_YEAR}" -lt 2026 ]; then
    echo "[ERROR] System year is ${CURRENT_YEAR}. Date year >= 2026 is required for this lab." >&2
    exit 1
fi

# 3. Environment & Prerequisites assertion
if [ ! -f "${SYSTEM_XML}" ]; then
    echo "[ERROR] Required file ${SYSTEM_XML} does not exist." >&2
    exit 1
fi

if ! rpm -q tomcat >/dev/null 2>&1; then
    echo "[ERROR] Tomcat RPM package is not installed." >&2
    exit 1
fi

TOMCAT_VERSION=$(rpm -q --qf "%{VERSION}" tomcat 2>/dev/null || true)
if [[ ! "${TOMCAT_VERSION}" =~ ^7\. ]]; then
    echo "[ERROR] Detected Tomcat version '${TOMCAT_VERSION}'. Lab requires Tomcat major version 7." >&2
    exit 1
fi

for tool in openssl keytool curl nmap python; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "[ERROR] Required prerequisite binary '${tool}' was not found in PATH." >&2
        exit 1
    fi
done

# -----------------------------------------------------------------------------
# Function: collect_verify_evidence
# Runs non-destructive verification tests and writes public evidence
# -----------------------------------------------------------------------------
collect_verify_evidence() {
    echo "[INFO] Running verification checks and generating public evidence in ${PUBLIC_DIR}..."
    mkdir -p "${PUBLIC_DIR}"
    chmod 755 "${PUBLIC_DIR}"

    if [ ! -f "${PASS_FILE}" ]; then
        echo "[ERROR] Password file ${PASS_FILE} not found. Cannot perform verification." >&2
        return 1
    fi
    LOCAL_KEY_PASS=$(cat "${PASS_FILE}")

    # 1. Environment & software versions
    {
        echo "=== Lab Environment Versions ==="
        echo "Timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        echo "Kernel: $(uname -r)"
        if [ -f /etc/redhat-release ]; then
            echo "OS: $(cat /etc/redhat-release)"
        fi
        echo "Tomcat RPM: $(rpm -q tomcat)"
        echo "OpenSSL: $(openssl version 2>&1)"
        echo "Java: $(java -version 2>&1 | head -n 2)"
        echo "Curl: $(curl --version 2>&1 | head -n 1)"
        echo "Nmap: $(nmap --version 2>&1 | head -n 1)"
    } > "${PUBLIC_DIR}/versions.txt"

    # 2. Textual certificates and public PEM exports
    if [ -f "${WORK_DIR}/tomcat.csr" ]; then
        openssl req -in "${WORK_DIR}/tomcat.csr" -noout -text > "${PUBLIC_DIR}/tomcat_csr.txt"
    fi

    if [ -f "${WORK_DIR}/rootCA.pem" ]; then
        cp -f "${WORK_DIR}/rootCA.pem" "${PUBLIC_DIR}/rootCA.pem"
        chmod 644 "${PUBLIC_DIR}/rootCA.pem"
        openssl x509 -in "${WORK_DIR}/rootCA.pem" -noout -text > "${PUBLIC_DIR}/rootCA_text.txt"
    fi

    if [ -f "${WORK_DIR}/tomcat.crt" ]; then
        cp -f "${WORK_DIR}/tomcat.crt" "${PUBLIC_DIR}/tomcat.crt"
        chmod 644 "${PUBLIC_DIR}/tomcat.crt"
        openssl x509 -in "${WORK_DIR}/tomcat.crt" -noout -text > "${PUBLIC_DIR}/tomcat_text.txt"
    fi

    # 3. SHA-256 certificate fingerprints
    {
        echo "=== Certificate Fingerprints (SHA-256) ==="
        if [ -f "${WORK_DIR}/rootCA.pem" ]; then
            echo -n "rootCA.pem: "
            openssl x509 -in "${WORK_DIR}/rootCA.pem" -noout -fingerprint -sha256
        fi
        if [ -f "${WORK_DIR}/tomcat.crt" ]; then
            echo -n "tomcat.crt: "
            openssl x509 -in "${WORK_DIR}/tomcat.crt" -noout -fingerprint -sha256
        fi
    } > "${PUBLIC_DIR}/cert_fingerprints.txt"

    # 4. Keytool listings (PKCS12 and final JKS)
    if [ -f "${WORK_DIR}/tomcat.p12" ]; then
        keytool -list -v -keystore "${WORK_DIR}/tomcat.p12" -storetype PKCS12 -storepass "${LOCAL_KEY_PASS}" > "${PUBLIC_DIR}/keytool_p12_list.txt" 2>&1
    fi

    if [ -f "${JKS_DEST}" ]; then
        keytool -list -v -keystore "${JKS_DEST}" -storepass "${LOCAL_KEY_PASS}" > "${PUBLIC_DIR}/keytool_jks_list.txt" 2>&1
    fi

    # 5. curl baseline HTTP 8080
    curl --max-time 15 -sS -I "http://${SERVER_IP}:8080/" > "${PUBLIC_DIR}/curl_baseline_8080.txt" 2>&1 || true

    # 6. curl teacher -k baseline (explicitly bypasses certificate validation)
    curl --max-time 15 -I -v -k "https://${SERVER_IP}:8443/" > "${PUBLIC_DIR}/curl_insecure_k_baseline.txt" 2>&1 || true

    # 7. curl HTTPS test: No CA provided (expected NEGATIVE test: must fail)
    run_capture_rc CODE_NO_CA curl --max-time 15 -I -v "https://${SERVER_IP}:8443/" > "${PUBLIC_DIR}/curl_no_ca_fail.txt" 2>&1


    # 8. curl HTTPS test: Explicit CA via IP address (expected POSITIVE test: must succeed)
    run_capture_rc CODE_CA_IP curl --max-time 15 -I -v --cacert "${PUBLIC_DIR}/rootCA.pem" "https://${SERVER_IP}:8443/" > "${PUBLIC_DIR}/curl_ca_ip_success.txt" 2>&1


    # 9. curl HTTPS test: Explicit CA via DNS name using --resolve (no /etc/hosts edit)
    run_capture_rc CODE_CA_DNS curl --max-time 15 -I -v --cacert "${PUBLIC_DIR}/rootCA.pem" --resolve "${SERVER_DNS}:8443:${SERVER_IP}" "https://${SERVER_DNS}:8443/" > "${PUBLIC_DIR}/curl_ca_dns_success.txt" 2>&1


    # 10. curl HTTPS test: Wrong hostname (expected NEGATIVE test: SAN mismatch, must fail)
    run_capture_rc CODE_WRONGHOST curl --max-time 15 -I -v --cacert "${PUBLIC_DIR}/rootCA.pem" --resolve "wrong-host.lab:8443:${SERVER_IP}" "https://wrong-host.lab:8443/" > "${PUBLIC_DIR}/curl_wronghost_fail.txt" 2>&1


    {
        echo "=== Curl Exit Code Evaluation ==="
        echo "No-CA Exit Code: ${CODE_NO_CA} (expected != 0)"
        echo "Explicit-CA IP Exit Code: ${CODE_CA_IP} (expected 0)"
        echo "Explicit-CA DNS Exit Code: ${CODE_CA_DNS} (expected 0)"
        echo "Wrong-Host Exit Code: ${CODE_WRONGHOST} (expected != 0)"
    } > "${PUBLIC_DIR}/curl_exit_codes.txt"

    # 11. OpenSSL s_client handshake with -verify_return_error
    run_capture_rc CODE_OPENSSL timeout 20 openssl s_client -connect "${SERVER_IP}:8443" \
        -CAfile "${PUBLIC_DIR}/rootCA.pem" \
        -servername "${SERVER_DNS}" \
        -verify_return_error \
        -showcerts > "${PUBLIC_DIR}/openssl_sclient_handshake.txt" 2>&1 < /dev/null

    echo "openssl_verify_return_error_exit_code=${CODE_OPENSSL}" > "${PUBLIC_DIR}/openssl_exit_code.txt"

    # 12. Nmap ssl-cert and ssl-enum-ciphers
    run_capture_rc CODE_NMAP_CERT timeout 90 nmap -p 8443 --script ssl-cert "${SERVER_IP}" > "${PUBLIC_DIR}/nmap_ssl_cert.txt" 2>&1


    run_capture_rc CODE_NMAP_CIPHER timeout 90 nmap -p 8443 --script ssl-enum-ciphers "${SERVER_IP}" > "${PUBLIC_DIR}/nmap_ssl_ciphers.txt" 2>&1


    {
        echo "=== Nmap Verification Summary ==="
        echo "nmap_ssl_cert_exit_code=${CODE_NMAP_CERT}"
        echo "nmap_ssl_ciphers_exit_code=${CODE_NMAP_CIPHER}"
    } > "${PUBLIC_DIR}/nmap_summary.txt"

    [ "${CODE_NO_CA}" -eq 60 ] || { echo 'No-CA test did not fail with curl60'; return 1; }
    grep -Eiq 'issuer.*not recognized|certificate.*not.*trusted|SEC_ERROR_UNKNOWN_ISSUER|unable to get.*issuer' "${PUBLIC_DIR}/curl_no_ca_fail.txt" || return 1
    [ "${CODE_CA_IP}" -eq 0 ] && grep -q '< HTTP/1.1 200' "${PUBLIC_DIR}/curl_ca_ip_success.txt" || return 1
    [ "${CODE_CA_DNS}" -eq 0 ] && grep -q '< HTTP/1.1 200' "${PUBLIC_DIR}/curl_ca_dns_success.txt" || return 1
    { [ "${CODE_WRONGHOST}" -eq 51 ] || [ "${CODE_WRONGHOST}" -eq 60 ]; } || return 1
    grep -Eiq 'does not match|SSL_ERROR_BAD_CERT_DOMAIN|domain name|no alternative certificate subject' "${PUBLIC_DIR}/curl_wronghost_fail.txt" || return 1
    [ "${CODE_OPENSSL}" -eq 0 ] && grep -q 'Verify return code: 0 (ok)' "${PUBLIC_DIR}/openssl_sclient_handshake.txt" || return 1
    [ "${CODE_NMAP_CERT}" -eq 0 ] && grep -q 'Subject: commonName=10.20.30.10' "${PUBLIC_DIR}/nmap_ssl_cert.txt" || return 1
    [ "${CODE_NMAP_CIPHER}" -eq 0 ] && grep -q 'TLSv1.2:' "${PUBLIC_DIR}/nmap_ssl_ciphers.txt" || return 1
    if grep -Eq 'TLSv1.0:|TLSv1.1:|RC4|3DES' "${PUBLIC_DIR}/nmap_ssl_ciphers.txt"; then echo 'Unexpected protocol/cipher'; return 1; fi
    echo 'All strict trust, hostname, chain, keystore and nmap checks passed.' > "${PUBLIC_DIR}/acceptance.txt"
    chmod 644 "${PUBLIC_DIR}"/*
    echo "[INFO] Verification checks complete. Evidence written to ${PUBLIC_DIR}."
}

# -----------------------------------------------------------------------------
# Mode: STOP
# -----------------------------------------------------------------------------
if [ "${1:-}" = "stop" ]; then
    echo "[INFO] Stopping Tomcat service..."
    systemctl stop tomcat
    echo "[INFO] Tomcat service stopped."
    exit 0
fi

# -----------------------------------------------------------------------------
# Mode: VERIFY
# -----------------------------------------------------------------------------
if [ "${1:-}" = "verify" ]; then
    if [ ! -f "${JKS_DEST}" ]; then
        echo "[ERROR] Environment is not yet initialized. Run './server-lab.sh setup' first." >&2
        exit 1
    fi
    collect_verify_evidence
    exit 0
fi

# -----------------------------------------------------------------------------
# Mode: SETUP
# -----------------------------------------------------------------------------
if [ "${1:-}" = "setup" ]; then
    # Idempotency check: fail if already initialized
    if [ -f "${INIT_FLAG}" ] || [ -f "${JKS_DEST}" ]; then
        echo "[ERROR] Setup fail-safe: Lab already initialized (${INIT_FLAG} or ${JKS_DEST} exists)." >&2
        echo "Silently regenerating keys is forbidden. Please verify or review manually." >&2
        exit 1
    fi

    echo "[INFO] Initializing Tomcat 7 TLS Lab..."
    umask 077
    mkdir -p "${WORK_DIR}"
    mkdir -p "${PUBLIC_DIR}"
    chmod 700 "${WORK_DIR}"
    chmod 755 "${PUBLIC_DIR}"

    # Generate 16-character alphanumeric private random password
    KEY_PASS=$(openssl rand -hex 16)
    if [ "${#KEY_PASS}" -lt 12 ]; then
        echo "[ERROR] Failed to generate a secure random password of length >= 12." >&2
        exit 1
    fi
    printf "%s" "${KEY_PASS}" > "${PASS_FILE}"
    chmod 600 "${PASS_FILE}"

    # Step 1: Generate RSA 4096 Root CA key
    echo "[STEP 1/11] Generating Root CA private key (RSA 4096)..."
    openssl genrsa -out "${WORK_DIR}/rootCA.key" 4096 2>/dev/null

    # Step 2: Generate Root CA certificate (10 years / 3650 days) with CA:TRUE, keyCertSign, cRLSign
    echo "[STEP 2/11] Creating Course Lab Root CA self-signed certificate (3650 days)..."
    cat <<'EOF' > "${WORK_DIR}/rootCA.cnf"
[ req ]
distinguished_name = req_distinguished_name
prompt = no
x509_extensions = v3_ca

[ req_distinguished_name ]
C = TW
ST = Taiwan
L = Taichung
O = Course Lab
OU = TLS
CN = Course Lab Root CA

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, keyCertSign, cRLSign
EOF
    openssl req -new -x509 -days 3650 -key "${WORK_DIR}/rootCA.key" \
        -out "${WORK_DIR}/rootCA.pem" -config "${WORK_DIR}/rootCA.cnf" 2>/dev/null

    # Step 3: Generate RSA 2048 Tomcat server key
    echo "[STEP 3/11] Generating Tomcat server private key (RSA 2048)..."
    openssl genrsa -out "${WORK_DIR}/tomcat.key" 2048 2>/dev/null

    # Step 4: Generate CSR for Tomcat server (synthetic DN)
    echo "[STEP 4/11] Generating CSR with synthetic DN (CN=10.20.30.10)..."
    cat <<'EOF' > "${WORK_DIR}/tomcat_req.cnf"
[ req ]
distinguished_name = req_distinguished_name
prompt = no

[ req_distinguished_name ]
C = TW
ST = Taiwan
L = Taichung
O = Course Lab
OU = TLS
CN = 10.20.30.10
EOF
    openssl req -new -key "${WORK_DIR}/tomcat.key" \
        -out "${WORK_DIR}/tomcat.csr" -config "${WORK_DIR}/tomcat_req.cnf" 2>/dev/null

    # Step 5: Prepare SAN extension configuration (san.cnf)
    echo "[STEP 5/11] Preparing SAN extension configuration..."
    cat <<'EOF' > "${WORK_DIR}/san.cnf"
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = Tomcat-SSL
DNS.2 = tomcat-ssl
IP.1 = 10.20.30.10
EOF

    # Step 6: Sign server certificate with Root CA (365 days)
    echo "[STEP 6/11] Signing Tomcat leaf certificate with Root CA (365 days)..."
    openssl x509 -req -in "${WORK_DIR}/tomcat.csr" \
        -CA "${WORK_DIR}/rootCA.pem" \
        -CAkey "${WORK_DIR}/rootCA.key" \
        -CAcreateserial \
        -out "${WORK_DIR}/tomcat.crt" \
        -days 365 \
        -extfile "${WORK_DIR}/san.cnf" 2>/dev/null

    # Step 7: Create PKCS12 bundle (tomcat.p12) with cert, key, and CA
    echo "[STEP 7/11] Bundling certificate chain and private key into PKCS12 (tomcat.p12)..."
    openssl pkcs12 -export \
        -in "${WORK_DIR}/tomcat.crt" \
        -inkey "${WORK_DIR}/tomcat.key" \
        -certfile "${WORK_DIR}/rootCA.pem" \
        -out "${WORK_DIR}/tomcat.p12" \
        -name tomcat \
        -passout "file:${PASS_FILE}"

    # Step 8: Initialize JKS and import Root CA as trustedCertEntry
    echo "[STEP 8/11] Importing Root CA into JKS (alias: rootca)..."
    keytool -importcert -trustcacerts -noprompt \
        -alias rootca \
        -file "${WORK_DIR}/rootCA.pem" \
        -keystore "${WORK_DIR}/keystore.jks" \
        -storepass "${KEY_PASS}" >/dev/null 2>&1

    keytool -list -v -keystore "${WORK_DIR}/keystore.jks" -storepass "${KEY_PASS}" > "${PUBLIC_DIR}/keytool_root_only.txt" 2>&1

    # Step 9: Import PKCS12 into JKS (PrivateKeyEntry with 2-cert chain)
    echo "[STEP 9/11] Importing PKCS12 into JKS (alias: tomcat)..."
    keytool -importkeystore \
        -srckeystore "${WORK_DIR}/tomcat.p12" \
        -srcstoretype PKCS12 \
        -srcstorepass "${KEY_PASS}" \
        -destkeystore "${WORK_DIR}/keystore.jks" \
        -deststoretype JKS \
        -deststorepass "${KEY_PASS}" \
        -alias tomcat >/dev/null 2>&1

    # Step 10: Deploy JKS to /etc/tomcat/keystore.jks with ownership root:tomcat 0640
    echo "[STEP 10/11] Deploying keystore to ${JKS_DEST}..."
    cp -f "${WORK_DIR}/keystore.jks" "${JKS_DEST}"
    chown root:tomcat "${JKS_DEST}"
    chmod 0640 "${JKS_DEST}"

    # Step 11: Configure /etc/tomcat/server.xml
    echo "[STEP 11/11] Configuring Tomcat Connector in ${SYSTEM_XML}..."
    if [ ! -f "${BACKUP_XML}" ]; then
        cp -p "${SYSTEM_XML}" "${BACKUP_XML}"
        chmod 600 "${BACKUP_XML}"
    fi

    # Use guest Python (Python 2.7 on CentOS 7) for safe, precise XML modification
    python - <<PYEOF
import sys, re

xml_path = "${SYSTEM_XML}"
pass_path = "${PASS_FILE}"

with open(pass_path, 'r') as pf:
    keystore_pass = pf.read().strip()

with open(xml_path, 'r') as f:
    content = f.read()

# Assert no active port 8443 connector exists
# Strip XML comments first to ensure we only look at active elements
uncommented = re.sub(r'<!--.*?-->', '', content, flags=re.DOTALL)
if re.search(r'<Connector\s+[^>]*port\s*=\s*["\']8443["\']', uncommented):
    sys.stderr.write("[ERROR] Active port 8443 Connector already present in " + xml_path + "\n")
    sys.exit(1)

# Teacher 8 AES-CBC cipher suite list (restricted TLSv1.2, no RC4, no 3DES)
ciphers = (
    "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,"
    "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,"
    "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,"
    "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,"
    "TLS_RSA_WITH_AES_128_CBC_SHA256,"
    "TLS_RSA_WITH_AES_128_CBC_SHA,"
    "TLS_RSA_WITH_AES_256_CBC_SHA256,"
    "TLS_RSA_WITH_AES_256_CBC_SHA"
)

connector_snippet = (
    '\n    <!-- Managed Course Lab TLS Connector (8443) -->\n'
    '    <Connector port="8443" protocol="org.apache.coyote.http11.Http11NioProtocol"\n'
    '               maxThreads="150" SSLEnabled="true" scheme="https" secure="true"\n'
    '               clientAuth="false" sslProtocol="TLS" sslEnabledProtocols="TLSv1.2"\n'
    '               ciphers="' + ciphers + '"\n'
    '               keystoreFile="' + "${JKS_DEST}" + '"\n'
    '               keystorePass="' + keystore_pass + '"\n'
    '               keystoreType="JKS"\n'
    '               keyAlias="tomcat" />\n\n'
)

if '</Service>' not in content:
    sys.stderr.write("[ERROR] Could not find closing </Service> tag in " + xml_path + "\n")
    sys.exit(1)

new_content = content.replace('</Service>', connector_snippet + '</Service>', 1)

with open(xml_path, 'w') as f:
    f.write(new_content)

print("[INFO] Successfully injected 8443 NIO JSSE Connector into " + xml_path)
PYEOF

    chown root:tomcat "${SYSTEM_XML}"
    chmod 0640 "${SYSTEM_XML}"


    # Restart Tomcat service and retry bounded 30s
    echo "[INFO] Restarting Tomcat service..."
    systemctl restart tomcat

    echo "[INFO] Bounded health check (up to 30s) waiting for HTTPS port 8443..."
    SUCCESS=0
    for i in $(seq 1 30); do
        HTTP_CODE=$(curl --max-time 3 -k -s -o /dev/null -w "%{http_code}" "https://127.0.0.1:8443/" 2>/dev/null || true)
        if [ "${HTTP_CODE}" = "200" ]; then
            echo "[INFO] Tomcat HTTPS listener is active and returned HTTP 200 on attempt ${i}."
            SUCCESS=1
            break
        fi
        sleep 1
    done

    if [ "${SUCCESS}" -ne 1 ]; then
        echo "[ERROR] Tomcat did not respond with HTTP 200 on port 8443 within 30 seconds." >&2
        exit 1
    fi

    # Run verification suite and output public evidence
    collect_verify_evidence
    touch "${INIT_FLAG}"
    echo "[INFO] Setup successfully completed."
    exit 0
fi

# Default usage if unknown mode
echo "Usage: $0 {setup|verify|stop}" >&2
exit 1

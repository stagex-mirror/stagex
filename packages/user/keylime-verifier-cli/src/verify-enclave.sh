#!/bin/sh
# verify-enclave — verify a remote enclave via Keylime agent
#
# Usage: verify-enclave <agent-ip> [--port 8891]
#
# Connects to the remote Keylime agent, retrieves attestation data,
# and reports PCR values and TPM identity.

AGENT_IP="${1:?Usage: verify-enclave <agent-ip>}"
AGENT_PORT="${PORT:-8891}"
AGENT_URL="http://${AGENT_IP}:${AGENT_PORT}"

echo "=== Keylime Enclave Verification ==="
echo "Target: ${AGENT_URL}"
echo

# Get agent identity and TPM info
echo "--- Agent Identity ---"
curl -sf "${AGENT_URL}/v1/identity" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for key in ['uuid', 'tpm_policy', 'boot_time']:
        if key in data:
            print(f'{key}: {data[key]}')
except:
    print(json.dumps(json.load(sys.stdin), indent=2))
" 2>/dev/null || echo "Failed to get identity"

echo
echo "--- PCR Values ---"
curl -sf "${AGENT_URL}/v1/tpm/pcrs" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'pcr_values' in data:
        for pcr, value in sorted(data['pcr_values'].items()):
            if value and value != '00'*32:
                print(f'PCR {pcr}: {value}')
except:
    print(json.dumps(json.load(sys.stdin), indent=2))
" 2>/dev/null || echo "Failed to get PCRs"

echo
echo "--- TPM Properties ---"
curl -sf "${AGENT_URL}/v1/tpm/properties" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for key in ['tpm_version', 'tpm_manufacturer']:
        if key in data:
            print(f'{key}: {data[key]}')
except:
    print(json.dumps(json.load(sys.stdin), indent=2))
" 2>/dev/null || echo "Failed to get TPM properties"

echo
echo "=== Verification Complete ==="
echo "Compare PCR 7 with expected: 65CAF8DD1E0EA7A6347B635D2B379C93B9A1351EDC2AFC3ECDA700E534EB3068"

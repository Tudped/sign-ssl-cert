#!/bin/bash
# Stop script on error
set -e

# Default certificate values
CERT_DAY=3650
CERT_NAME="myCert"

CONFIG_FILE=""

# Parse -c option
while getopts "c:" opt; do
  case "$opt" in
    c) CONFIG_FILE="$OPTARG" ;;
    *) echo "Usage: $0 -c <config_file>"; exit 1 ;;
  esac
done

# Require -c
if [ -z "$CONFIG_FILE" ]; then
  echo "Error: Missing required -c <config_file> argument"
  exit 1
fi

# Check CNF exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file '$CONFIG_FILE' not found."
  exit 1
fi

# Extract DN defaults from CNF
DEFAULT_C=$(grep -E "^C\s*=" "$CONFIG_FILE" | awk -F= '{print $2}' | xargs)
DEFAULT_ST=$(grep -E "^ST\s*=" "$CONFIG_FILE" | awk -F= '{print $2}' | xargs)
DEFAULT_L=$(grep -E "^L\s*=" "$CONFIG_FILE" | awk -F= '{print $2}' | xargs)
DEFAULT_O=$(grep -E "^O\s*=" "$CONFIG_FILE" | awk -F= '{print $2}' | xargs)
DEFAULT_OU=$(grep -E "^OU\s*=" "$CONFIG_FILE" | awk -F= '{print $2}' | xargs)
DEFAULT_CN=$(grep -E "^CN\s*=" "$CONFIG_FILE" | awk -F= '{print $2}' | xargs)

# Prompt user for DN values
read -p "Certificate name [$CERT_NAME]: " input; CERT_NAME=${input:-$CERT_NAME}
read -p "Certificate validity (days) [$CERT_DAY]: " input; CERT_DAY=${input:-$CERT_DAY}
read -p "Country [$DEFAULT_C]: " USER_C; USER_C=${USER_C:-$DEFAULT_C}
read -p "State [$DEFAULT_ST]: " USER_ST; USER_ST=${USER_ST:-$DEFAULT_ST}
read -p "City [$DEFAULT_L]: " USER_L; USER_L=${USER_L:-$DEFAULT_L}
read -p "Organization [$DEFAULT_O]: " USER_O; USER_O=${USER_O:-$DEFAULT_O}
read -p "Organizational Unit [$DEFAULT_OU]: " USER_OU; USER_OU=${USER_OU:-$DEFAULT_OU}
read -p "Common Name [$DEFAULT_CN]: " USER_CN; USER_CN=${USER_CN:-$DEFAULT_CN}

# Create output folder
OUTPUT_DIR="./$CERT_NAME"
mkdir -p "$OUTPUT_DIR"

# Copy CNF into folder
CONFIG_BASENAME=$(basename "$CONFIG_FILE")
cp "$CONFIG_FILE" "$OUTPUT_DIR/$CONFIG_BASENAME"

# Summary & confirmation
echo
echo "Summary:"
echo "Certificate name: $CERT_NAME"
echo "Validity (days): $CERT_DAY"
echo "Subject: /C=$USER_C/ST=$USER_ST/L=$USER_L/O=$USER_O/OU=$USER_OU/CN=$USER_CN"
echo "Config file: $CONFIG_BASENAME (copied into folder)"
echo "Output folder: $OUTPUT_DIR"
read -p "Proceed with certificate generation? (y/n): " confirm
[[ $confirm != [yY] ]] && echo "Aborted." && exit 1

echo
echo "Generating certificates for: $CERT_NAME"

# Generate CA if it doesn't exist
if [ ! -f "$OUTPUT_DIR/myCA.key.pem" ] || [ ! -f "$OUTPUT_DIR/myCA.crt.pem" ]; then
    echo "Generating CA key and certificate..."
    openssl genrsa -out "$OUTPUT_DIR/myCA.key.pem" 4096
    openssl req -x509 -new -nodes -key "$OUTPUT_DIR/myCA.key.pem" -sha256 -days "$CERT_DAY" \
        -out "$OUTPUT_DIR/myCA.crt.pem" \
        -subj "/C=$USER_C/ST=$USER_ST/L=$USER_L/O=$USER_O/OU=$USER_OU/CN=$USER_CN"
else
    echo "Using existing CA certificate."
fi

# Backup old server key/cert/CSR
TIMESTAMP=$(date +%Y%m%d%H%M%S)
for FILE in "${CERT_NAME}.key" "${CERT_NAME}.crt" "${CERT_NAME}.csr"; do
    if [ -f "$OUTPUT_DIR/$FILE" ]; then
        BACKUP_FILE="$OUTPUT_DIR/${FILE}.bak.$TIMESTAMP"
        echo "Backing up existing $FILE → $BACKUP_FILE"
        mv "$OUTPUT_DIR/$FILE" "$BACKUP_FILE"
    fi
done

# Generate server key and CSR using DN from prompts, SANs from CNF
echo "Generating key and CSR for SAN..."
openssl req -new -nodes -out "$OUTPUT_DIR/${CERT_NAME}.csr" -newkey rsa:2048 \
    -keyout "$OUTPUT_DIR/${CERT_NAME}.key" \
    -subj "/C=$USER_C/ST=$USER_ST/L=$USER_L/O=$USER_O/OU=$USER_OU/CN=$USER_CN" \
    -config "$OUTPUT_DIR/$CONFIG_BASENAME"

# Secure private keys
chmod 600 "$OUTPUT_DIR/myCA.key.pem" "$OUTPUT_DIR/${CERT_NAME}.key"

# Sign server certificate with CA
echo "Signing certificate with CA..."
openssl x509 -req -in "$OUTPUT_DIR/${CERT_NAME}.csr" \
    -CA "$OUTPUT_DIR/myCA.crt.pem" -CAkey "$OUTPUT_DIR/myCA.key.pem" -CAcreateserial \
    -out "$OUTPUT_DIR/${CERT_NAME}.crt" -days "$CERT_DAY" -sha256 \
    -extfile "$OUTPUT_DIR/$CONFIG_BASENAME" -extensions req_ext

# Final messages
echo
echo "  Done. Generated certificate: $OUTPUT_DIR/${CERT_NAME}.crt"
echo
echo "  Files generated in folder '$OUTPUT_DIR':"
echo "  Server certificate: ${CERT_NAME}.crt   → use in Nginx ssl_certificate"
echo "  Server private key: ${CERT_NAME}.key   → use in Nginx ssl_certificate_key"
echo "  CSR:                ${CERT_NAME}.csr   → optional"
echo "  CA certificate:     myCA.crt.pem       → install in client trust store if needed"
echo "  Config file:        $CONFIG_BASENAME   → copied into folder"
echo
echo "  Keep private keys secure. Do NOT share myCA.key.pem or ${CERT_NAME}.key"
echo
echo "  Any previous server keys/certs have been backed up with timestamp in the same folder."

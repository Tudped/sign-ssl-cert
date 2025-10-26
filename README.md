# SSL Certificate Generator with SAN Support

This repository contains a Bash script to generate self-signed SSL certificates with Subject Alternative Names (SANs) for local development or homelab use. The script uses a custom OpenSSL configuration file for SANs and organizes all generated files in a folder named after your certificate.

Note: This script is intended for homelabs, internal networks, or development use. It creates self-signed SAN certificates with a private CA. For public-facing HTTPS, tools like Certbot/Let’s Encrypt are simpler and trusted by browsers.

⚠️ Use at your own risk. The author is not responsible for any damage or misuse.

## Features

* Interactive prompts for certificate details (CN, OU, O, etc.) with default values.
* Reuses an existing CA certificate if available.
* Generates server key, CSR, and certificate with SANs from a `.cnf` file.
* Creates a folder named after the certificate (`$CERT_NAME`) to store all output files.
* Automatically backs up any existing server key/cert/CSR with a timestamp.
* Required `-c <config_file>` option for specifying SAN configuration file.
* Permissions are set securely on private keys.

## Requirements

* Bash shell
* OpenSSL installed (`openssl` command available)
* Linux or macOS environment

## Usage

1. Clone this repository:

```bash
git clone https://github.com/yourusername/ssl-cert-generator.git
cd ssl-cert-generator
```

2. Prepare your SAN configuration file (`*.cnf`), for example:

```ini
[ req ]
default_bits       = 2048
prompt             = no
default_md         = sha256
req_extensions     = req_ext
distinguished_name = dn

[ dn ]
C = US
ST = yourState
L = yourCity
O = pishare
OU = homelab
CN = *.home.base

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = *.home.base
DNS.2 = home.base
```

3. Run the script:

```bash
./createssl.sh -c wildcard_san.cnf
```

4. The script will prompt for certificate details (with defaults), create a folder named after the certificate, generate all files, and back up any existing files.

## Output

All generated files are stored in `./$CERT_NAME/`:

* `${CERT_NAME}.crt` → Server certificate (use in Nginx `ssl_certificate`)
* `${CERT_NAME}.key` → Server private key (use in Nginx `ssl_certificate_key`)
* `${CERT_NAME}.csr` → Certificate signing request (optional)
* `myCA.crt.pem` → CA certificate (install in client trust store if needed)
* `wildcard_san.cnf` → Copy of the SAN config used
* Backups of previous server cert/key/CSR are stored with timestamps

## Nginx Example

```nginx
server {
    listen 443 ssl;
    server_name yourdomain.tld;

    ssl_certificate     /path/to/Homelab/${CERT_NAME}.crt;
    ssl_certificate_key /path/to/Homelab/${CERT_NAME}.key;

    # Optional: trust CA for client authentication
    ssl_client_certificate /path/to/Homelab/myCA.crt.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
```

## Notes

* The CA certificate (`myCA.crt.pem`) is reused if it already exists.
* Ensure the output folder is writable. If owned by root, you may need:

```bash
sudo chown -R $(whoami):$(whoami) ./Homelab
```

* Keep private keys secure. Do **not** share `myCA.key.pem` or `${CERT_NAME}.key`.

## License

This project is licensed under the MIT License. See `LICENSE` for details.

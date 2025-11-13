#!/bin/bash
# Generate OPC UA demo certificates for testing
# These certificates are self-signed and valid for 10 years

set -e

CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$CERT_DIR"

# Server certificate - URI must match ApplicationUri in server config
# Using a generic URI that works with open62541 defaults
echo "Generating server certificate..."
openssl req -x509 -newkey rsa:2048 -keyout server_key.pem -out server_cert.pem -days 3650 -nodes \
    -subj "/CN=OPC UA Server/C=US/ST=State/L=City/O=Organization" \
    -addext "subjectAltName=URI:urn:open62541.server.application"

# Convert server certificate to DER format
openssl x509 -outform DER -in server_cert.pem -out server_cert.der
openssl rsa -outform DER -in server_key.pem -out server_key.der

# Client certificate - URI must match ApplicationUri in client config
echo "Generating client certificate..."
openssl req -x509 -newkey rsa:2048 -keyout client_key.pem -out client_cert.pem -days 3650 -nodes \
    -subj "/CN=OPC UA Client/C=US/ST=State/L=City/O=Organization" \
    -addext "subjectAltName=URI:urn:open62541.client.application"

# Convert client certificate to DER format
openssl x509 -outform DER -in client_cert.pem -out client_cert.der
openssl rsa -outform DER -in client_key.pem -out client_key.der

# Clean up PEM files
rm -f server_key.pem server_cert.pem client_key.pem client_cert.pem

echo "Certificates generated successfully!"
echo "Server: server_cert.der, server_key.der"
echo "Client: client_cert.der, client_key.der"


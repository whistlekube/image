#!/bin/bash

set -euxo pipefail

rootfs="$1"

# Make sure rootfs argument is passed
if [ -z "$rootfs" ]; then
    echo "Error: rootfs argument is required"
    exit 1
fi

pki_dir="${rootfs}/etc/kubernetes/pki"

mkdir -p ${pki_dir}/etcd

# Configuration variables
CLUSTER_NAME="kubernetes"
SERVICE_CIDR="10.96.0.0/12"
CLUSTER_DNS="10.96.0.10"
KUBERNETES_SERVICE_IP="10.96.0.1"

# Generate CA private key
openssl genrsa -out ${pki_dir}/ca.key 2048

# Generate CA certificate
openssl req -new -x509 -days 3650 -key ${pki_dir}/ca.key -out ${pki_dir}/ca.crt -subj "/CN=kubernetes-ca"

# Generate etcd CA private key
openssl genrsa -out ${pki_dir}/etcd/ca.key 2048

# Generate etcd CA certificate
openssl req -new -x509 -days 3650 -key ${pki_dir}/etcd/ca.key -out ${pki_dir}/etcd/ca.crt -subj "/CN=etcd-ca"

# Generate front-proxy CA private key
openssl genrsa -out ${pki_dir}/front-proxy-ca.key 2048

# Generate front-proxy CA certificate
openssl req -new -x509 -days 3650 -key ${pki_dir}/front-proxy-ca.key -out ${pki_dir}/front-proxy-ca.crt -subj "/CN=front-proxy-ca"

# Generate service account key pair
openssl genrsa -out ${pki_dir}/sa.key 2048
openssl rsa -in ${pki_dir}/sa.key -pubout -out ${pki_dir}/sa.pub

# Generate API server private key
openssl genrsa -out ${pki_dir}/apiserver.key 2048

# Create API server certificate signing request
cat > ${pki_dir}/apiserver.conf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = kube-apiserver

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
DNS.5 = localhost
IP.1 = ${KUBERNETES_SERVICE_IP}
IP.2 = 127.0.0.1
EOF

openssl req -new -key ${pki_dir}/apiserver.key -out ${pki_dir}/apiserver.csr -config ${pki_dir}/apiserver.conf

# Generate API server certificate
openssl x509 -req -in ${pki_dir}/apiserver.csr -CA ${pki_dir}/ca.crt -CAkey ${pki_dir}/ca.key -CAcreateserial -out ${pki_dir}/apiserver.crt -days 365 -extensions v3_req -extfile ${pki_dir}/apiserver.conf

# Generate API server kubelet client private key
openssl genrsa -out ${pki_dir}/apiserver-kubelet-client.key 2048

# Generate API server kubelet client certificate
openssl req -new -key ${pki_dir}/apiserver-kubelet-client.key -out ${pki_dir}/apiserver-kubelet-client.csr -subj "/CN=kube-apiserver-kubelet-client/O=system:masters"
openssl x509 -req -in ${pki_dir}/apiserver-kubelet-client.csr -CA ${pki_dir}/ca.crt -CAkey ${pki_dir}/ca.key -CAcreateserial -out ${pki_dir}/apiserver-kubelet-client.crt -days 365

# Generate front-proxy client private key
openssl genrsa -out ${pki_dir}/front-proxy-client.key 2048

# Generate front-proxy client certificate
openssl req -new -key ${pki_dir}/front-proxy-client.key -out ${pki_dir}/front-proxy-client.csr -subj "/CN=front-proxy-client"
openssl x509 -req -in ${pki_dir}/front-proxy-client.csr -CA ${pki_dir}/front-proxy-ca.crt -CAkey ${pki_dir}/front-proxy-ca.key -CAcreateserial -out ${pki_dir}/front-proxy-client.crt -days 365

# Generate etcd server private key
openssl genrsa -out ${pki_dir}/etcd/server.key 2048

# Create etcd server certificate signing request
cat > ${pki_dir}/etcd/server.conf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = etcd

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = etcd
IP.1 = 127.0.0.1
EOF

openssl req -new -key ${pki_dir}/etcd/server.key -out ${pki_dir}/etcd/server.csr -config ${pki_dir}/etcd/server.conf

# Generate etcd server certificate
openssl x509 -req -in ${pki_dir}/etcd/server.csr -CA ${pki_dir}/etcd/ca.crt -CAkey ${pki_dir}/etcd/ca.key -CAcreateserial -out ${pki_dir}/etcd/server.crt -days 365 -extensions v3_req -extfile ${pki_dir}/etcd/server.conf

# Generate etcd peer private key
openssl genrsa -out ${pki_dir}/etcd/peer.key 2048

# Generate etcd peer certificate
openssl req -new -key ${pki_dir}/etcd/peer.key -out ${pki_dir}/etcd/peer.csr -config ${pki_dir}/etcd/server.conf
openssl x509 -req -in ${pki_dir}/etcd/peer.csr -CA ${pki_dir}/etcd/ca.crt -CAkey ${pki_dir}/etcd/ca.key -CAcreateserial -out ${pki_dir}/etcd/peer.crt -days 365 -extensions v3_req -extfile ${pki_dir}/etcd/server.conf

# Generate etcd healthcheck client private key
openssl genrsa -out ${pki_dir}/etcd/healthcheck-client.key 2048

# Generate etcd healthcheck client certificate
openssl req -new -key ${pki_dir}/etcd/healthcheck-client.key -out ${pki_dir}/etcd/healthcheck-client.csr -subj "/CN=kube-etcd-healthcheck-client/O=system:masters"
openssl x509 -req -in ${pki_dir}/etcd/healthcheck-client.csr -CA ${pki_dir}/etcd/ca.crt -CAkey ${pki_dir}/etcd/ca.key -CAcreateserial -out ${pki_dir}/etcd/healthcheck-client.crt -days 365

# Generate API server etcd client private key
openssl genrsa -out ${pki_dir}/apiserver-etcd-client.key 2048

# Generate API server etcd client certificate
openssl req -new -key ${pki_dir}/apiserver-etcd-client.key -out ${pki_dir}/apiserver-etcd-client.csr -subj "/CN=kube-apiserver-etcd-client/O=system:masters"
openssl x509 -req -in ${pki_dir}/apiserver-etcd-client.csr -CA ${pki_dir}/etcd/ca.crt -CAkey ${pki_dir}/etcd/ca.key -CAcreateserial -out ${pki_dir}/apiserver-etcd-client.crt -days 365

# Set proper permissions
chmod 600 ${pki_dir}/*.key ${pki_dir}/etcd/*.key
chmod 644 ${pki_dir}/*.crt ${pki_dir}/*.pub ${pki_dir}/etcd/*.crt

# Clean up temporary files
rm -f ${pki_dir}/*.csr ${pki_dir}/*.conf ${pki_dir}/etcd/*.csr ${pki_dir}/etcd/*.conf ${pki_dir}/*.srl ${pki_dir}/etcd/*.srl

echo "Kubernetes PKI certificates generated successfully in ${pki_dir}"
echo "Generated certificates:"
echo "  - Cluster CA: ca.crt/ca.key"
echo "  - etcd CA: etcd/ca.crt/etcd/ca.key"
echo "  - Front Proxy CA: front-proxy-ca.crt/front-proxy-ca.key"
echo "  - Service Account: sa.key/sa.pub"
echo "  - API Server: apiserver.crt/apiserver.key"
echo "  - API Server Kubelet Client: apiserver-kubelet-client.crt/apiserver-kubelet-client.key"
echo "  - API Server etcd Client: apiserver-etcd-client.crt/apiserver-etcd-client.key"
echo "  - Front Proxy Client: front-proxy-client.crt/front-proxy-client.key"
echo "  - etcd Server: etcd/server.crt/etcd/server.key"
echo "  - etcd Peer: etcd/peer.crt/etcd/peer.key"
echo "  - etcd Healthcheck Client: etcd/healthcheck-client.crt/etcd/healthcheck-client.key"








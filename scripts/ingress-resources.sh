#!/usr/bin/env bash

# File server ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: file-server-ingress
  namespace: openftth
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-body-size: 25m
spec:
  rules:
  - host: files.openftth.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: file-server-go-http-file-server
            port:
              number: 80
EOF

# Routenetwork tileserver
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: routenetwork-tileserver-ingress
  namespace: openftth
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: tiles-routenetwork.openftth.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: routenetwork-tileserver-mbtileserver
            port:
              number: 80
EOF

# Basemap tileserver ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basemap-tileserver-ingress
  namespace: openftth
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: tiles-basemap.openftth.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: basemap-tileserver-mbtileserver
            port:
              number: 80
EOF

# Custom tileserver ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: custom-tileserver-ingress
  namespace: openftth
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: tiles-custom.openftth.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: custom-tileserver-mbtileserver
            port:
              number: 80
EOF

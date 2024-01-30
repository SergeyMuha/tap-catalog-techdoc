FROM docker:24.0.0-rc.1-dind
ADD ca.crt /usr/local/share/ca-certificates/ca.crt
RUN  chmod 644 /usr/local/share/ca-certificates/ca.crt && update-ca-certificates
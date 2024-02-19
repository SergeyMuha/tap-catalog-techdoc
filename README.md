Currently TAP 1.7.2 doesn't support techdoc generation with builder `local`. But sometimes for testing or demo purpose we would like to use local builder and local store. This repo contains workaround code snippet and step by step guide to patch-tap package.

We will update tap-gui deployment to have second contaner with docker that give us ability to generate techdoc locally. Theoretically we can store `output` in pvc. For now it is `Emptydir` volume.

<details>
<summary>Overlay YTT approach for PROD </summary>

First we need to create secret with overlay.

If dockerhub rate-limits pull requests and your contaner registry use selfsing CA you need rebuild dind image with your custom CA.

```
docker build . -t your-registry.example.com/path/dind:1.0
```
Update techdoc-overlay.yaml with new docker image and apply it

```
kubectl apply -f https://raw.githubusercontent.com/SergeyMuha/tap-catalog-techdoc/master/techdoc-overlay.yaml
```

Next update your tap-values.yaml with following snippet. With dockerImage you can provide your private registry.
```yaml
tap_gui:
....
    techdocs:
      generator: 
        runIn: 'docker'
        dockerImage: 'spotify/techdocs:v1.2.3'
      builder: 'local'
      publisher:
        type: 'local'
        local:
          publishDirectory: '/output'
    catalog:
      locations:
        - type: url
          target: https://github.com/SergeyMuha/tap-catalog-techdoc/blob/master/catalog-info.yaml
...
package_overlays:
  - name: tap-gui
    secrets:
      - name: techdoc-overlay
...
```

```
tanzu package installed update tap -p tap.tanzu.vmware.com -v 1.7.2 --values-file path-to-file/tap-values.yaml -n tap-install
```
For some reason you need to reopen page after first time generation.

</details>

<details>
<summary>Manual approach for DEV </summary>

tap-values.yaml snippet we need to use
```yaml
tap_gui:
....
    techdocs:
      generator: 
        runIn: 'docker'
        dockerImage: 'spotify/techdocs:v1.2.3'
      builder: 'local'
      publisher:
        type: 'local'
        local:
          publishDirectory: '/output'
    catalog:
      locations:
        - type: url
          target: https://github.com/SergeyMuha/tap-catalog-techdoc/blob/master/catalog-info.yaml
...
```
Sometime dockerhub can rate-limit pull request. With dockerImage you can provide your private repo. Be aware about selfsing CA.

We need to pause reconcilation for tap-gui package.
```bash 
kubectl patch pkgi tap -n tap-install -p '{"spec":{"paused":true}}' --type=merge
kubectl patch pkgi tap-gui -n tap-install -p '{"spec":{"paused":true}}' --type=merge
```
This is code snippet for patch.
```yaml
spec:
  template:
    spec:
      securityContext:
        # allowPrivilegeEscalation: true
        runAsGroup: 0
        runAsNonRoot: false
        runAsUser: 0
        fsGroup: 0
      containers:
      - args:
        command:
        - dockerd
        - '--host'
        - 'tcp://127.0.0.1:2375'
        env:
          - name: DOCKER_HOST
            value: 'tcp://localhost:2375'
        image: 'docker:24.0.0-rc.1-dind'
        imagePullPolicy: IfNotPresent
        name: dind-daemon
        volumeMounts:
          - mountPath: /tmp
            name: tmp
          - mountPath: /output
            name: output
          # - name: docker-socket
          #   mountPath: /var/run/docker.sock
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        securityContext:
          runAsUser: 0
          privileged: true
      - name: backstage
        env:
          - name: DOCKER_HOST
            value: 'tcp://localhost:2375'
        volumeMounts:
          - mountPath: /tmp
            name: tmp
          - mountPath: /output
            name: output
      volumes:
        - emptyDir: {}
          name: tmp
        - emptyDir: {}
          name: output
```
If dockerhub rate-limit pull requests and your contaner registry use selfsing CA you can rebuild dind with your custom CA.

```
docker build . -t your-registry.example.com/path/dind:1.0
```
Update tap-gui-dind-patch.yaml with new docker image and apply
```
kubectl patch deploy server -n tap-gui --patch-file tap-gui-dind-patch.yaml
```
For some reason you need to reopen page after first time.

</details>

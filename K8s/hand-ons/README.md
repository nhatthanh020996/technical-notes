# demo stack on a 3-node cluster

```
      internet
         │
   Service (LoadBalancer :80)
         │
   ┌─────▼─────┐  3 replicas, 1 per node
   │   nginx   │  reverse proxy, edge
   └─────┬─────┘
         │  ClusterIP :8080
   ┌─────▼─────┐  3 replicas, 1 per node
   │api-server │  stateless
   └──┬─────┬──┘
      │     │
 ┌────▼─┐ ┌─▼──────┐   1 replica each, StatefulSet + PVC,
 │redis │ │postgres│   anti-affinity keeps them on separate nodes
 └──────┘ └────────┘
```

## One thing about the diagram

Your sketch reads `api-server => redis => postgres`, a straight line. Redis
doesn't proxy to Postgres — it has no concept of an upstream database. So these
manifests wire **api-server to both**, with Redis as cache/session store and
Postgres as the system of record. That's almost certainly what you meant, but if
you actually intended a write-behind or queue-worker pattern (api writes to
Redis, a separate consumer drains it into Postgres), that's a fourth workload
and I'd need to add it.

## Deploy

```bash
# 1. Set real credentials first — 01-secrets.yaml ships with placeholders.
$EDITOR 01-secrets.yaml

# 2. Point at your real image.
$EDITOR 04-api-server.yaml     # or: kustomize edit set image ...

# 3. Apply.
kubectl apply -k .

# Ordering is handled by the initContainer and probes, so plain
# `kubectl apply -f .` works too — pods just crash-loop briefly.
```

## Verify

```bash
kubectl -n demo get pods -o wide            # confirm 1 nginx + 1 api per node
kubectl -n demo rollout status deploy/api-server
kubectl -n demo get pvc                     # both should be Bound

# End-to-end through the proxy:
kubectl -n demo port-forward svc/nginx 8080:80
curl -i localhost:8080/

# Database reachable from the app tier:
kubectl -n demo exec -it postgres-0 -- psql -U appuser -d appdb -c '\l'
kubectl -n demo exec -it redis-0 -- sh -c 'redis-cli -a "$REDIS_PASSWORD" --no-auth-warning ping'
```

## Before you call this production

**Storage class.** The PVCs use your cluster's default. `kubectl get sc` — if
nothing is marked `(default)`, both StatefulSets stay Pending. On bare metal
you likely want local-path-provisioner or Longhorn; uncomment
`storageClassName` to pin one explicitly.

**LoadBalancer.** On bare metal without MetalLB the nginx Service will sit at
`<pending>` forever. Change `type: LoadBalancer` to `NodePort`, or install
MetalLB. On a cloud provider it works as-is.

**Single-replica Postgres is a real single point of failure.** If its node dies,
the RWO volume is stuck there and the pod cannot reschedule — you are down until
the node returns. Three nodes doesn't fix this; `replicas: 3` on that
StatefulSet would give you three independent, diverging databases. When you need
HA, move to an operator (CloudNativePG is the current default choice) or a
managed database. Same story for Redis: HA means Sentinel or Cluster, not more
replicas.

**No backups are configured.** A PVC is not a backup. Add a CronJob running
`pg_dump` to object storage, or use the operator's built-in WAL archiving.

**No TLS.** Traffic is plaintext HTTP at the edge, and `sslmode=disable` to
Postgres. For real traffic, put an Ingress with cert-manager in front of (or
instead of) this nginx.

**Probe paths are guesses.** `/healthz` and `/readyz` in `04-api-server.yaml`
need to match your app. Keep the distinction: readiness should check Postgres
and Redis, liveness should not — a liveness probe that touches the database will
restart all three replicas simultaneously the moment the database hiccups, which
turns a brief blip into an outage.

**NetworkPolicy needs a CNI that enforces it.** Under flannel, the objects in
`06-networkpolicy.yaml` apply cleanly and do nothing at all. Test with an actual
connection attempt from an unrelated pod.

**ConfigMap changes don't restart pods.** Both nginx and Redis have a
`checksum/config` annotation for you to bump, or run
`kubectl -n demo rollout restart deploy/nginx`. Kustomize's
`configMapGenerator` automates this with a hash suffix if you'd rather.

**`readOnlyRootFilesystem: true` is set on every container.** If your api-server
writes anywhere outside `/tmp`, it will fail on first write — add an `emptyDir`
for that path rather than turning the flag off.

## Resource footprint

Requests total roughly **1.1 CPU / 1.6 GiB** across all 9 pods, so this fits
comfortably on three small nodes (2 vCPU / 4 GiB each) with room for a rolling
update surge.

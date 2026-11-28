# scrim and Agones

scrim is compatible with **Agones v1.62.0**. This page says where the two
differ, as a game server, a manifest, a matchmaker and an operator see
them, and what to change when moving from one to the other. Anything not
listed here is meant to behave as in Agones; if it does not, that is a bug
in scrim, and an [issue](https://github.com/ponyo877/scrim/issues) is
welcome.

## How the sameness is checked

scrim does not reimplement the Agones API. It uses the Agones Go module for
the resource types, and calls their own defaulting and validation, so a
manifest is judged by the same code. On top of that, CI checks behaviour
against Agones itself:

- **The conformance clients of every Agones SDK** (Go, REST and WebSocket,
  Python, C#, Node.js, Rust and C++) are built from the Agones source,
  unchanged, and run as scrim game servers until they shut themselves down.
- **A side-by-side comparison.** Agones v1.62.0 is installed in a kind
  cluster. The same GameServers, allocation requests and Fleet changes
  (scaling, a rolling update) are made there and on scrim, and what the two
  answer and store is compared field by field. Its first run found three
  places where scrim differed, and they were fixed.

The design document ([docs/design.md](design.md), in Japanese) has the
details of both.

## Following new releases of Agones

scrim is compatible with one release of Agones at a time: the one its
`go.mod` requires. Since the autumn of 2025, Agones has put out a release
about every six weeks. scrim moves to each one before Agones puts out the
next, so it is never more than one release behind. The pages of releases
after v0.2.0 say which Agones release each is compatible with.

A workflow looks for a new release of Agones every week. When there is
one, it tries the mechanical part of the move (the Go module, the
reference copy in `third_party/agones` and the version constant), builds,
runs the tests, and opens an issue with the result, the rest of the steps,
and every line that names the old release. The rest is done by hand.
scrim calls Agones' own code for the resource types, defaulting and
validation, so those follow the module. The controllers and the allocator
are scrim's own, though, and its tests check the behaviour of the old
release, so they would pass while a change Agones made there is missing.

## A game server

| | Agones | scrim |
|---|---|---|
| SDK protocol | gRPC, REST and WebSocket | the same, from the same generated code |
| SDK calls | Stable and Beta; Alpha behind feature gates | Stable and Beta, Counters and Lists included. The Alpha PlayerTracking calls answer `PlayerTracking not enabled`, as Agones does with its default gates |
| SDK ports | `AGONES_SDK_GRPC_PORT`, `AGONES_SDK_HTTP_PORT`, from `spec.sdkServer` | the same |
| `spec.sdkServer.logLevel` | sets the sidecar's log level; Debug notes every SDK call | the same |
| The sidecar | `agones-gameserver-sidecar`, the `agones-sdk` image | the same container name, scrim's own image (`--sidecar-image`) |
| A game container that exits | before Ready, the kubelet may restart it, as `restartPolicy` says; after Ready, the GameServer becomes Unhealthy | never restarted, before Ready or after: `restartPolicy` is ignored |

The SDK server that Agones runs beside a game server answers `UpdateList`
with an empty List, and so does scrim's. The local SDK server of Agones
(`sdk-server --local`) answers with the List as updated. A game tested only
against the local one may count on that.

## A manifest

scrim stores `GameServer`, `Fleet`, `GameServerSet` and `FleetAutoscaler`.
There are no CRDs and no `kubectl`: manifests go to `scrim apply -f`.
Agones also takes a `GameServerAllocation` through `kubectl create`; scrim
takes allocations only through the Allocation API, in its request format
(`scrim allocate -f` sends one from a file). `GameServerAllocationPolicy`
does not exist.

Feature gates are fixed at the defaults of v1.62.0 and cannot be changed.
Features that are Alpha or Dev in Agones are not available.

### The Pod template

A game server is a set of Docker containers, so only the part of the Pod
definition that Docker can express is honoured. Fields that would not change
what runs are accepted with a warning and ignored; every other field is
refused with its path and `not supported by scrim`.

| Honoured | Ignored, with a warning | Refused |
|---|---|---|
| `containers[]`: `name`, `image`, `command`, `args`, `workingDir`, `env` (literal values), `ports` (kept, not published), `resources` (`cpu` and `memory`), `volumeMounts`, `imagePullPolicy`, and of `securityContext` `runAsUser`, `runAsGroup` and `readOnlyRootFilesystem` | `nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`, `schedulerName`, `priorityClassName` | `initContainers` |
| `volumes[]`: `emptyDir` and `hostPath` | `serviceAccountName`, `automountServiceAccountToken` | volumes of any other kind, `configMap` and `secret` among them |
| `terminationGracePeriodSeconds` | `imagePullSecrets`: log in with `docker login` on each machine instead | `hostNetwork`, probes, `lifecycle`, `envFrom`, `env[].valueFrom` |
| More containers than one: they share the game server's network | `restartPolicy`, Pod-level `resources`, `terminationMessagePath` and `terminationMessagePolicy` | `hostPort` and `hostIP` on a container port |
| | of `emptyDir`, `medium` and `sizeLimit`; of `hostPath`, `type` | other resources than `cpu` and `memory`, other `securityContext` fields |
| | in a template's `metadata`, everything but labels and annotations | a container named `agones-gameserver-sidecar` |

### Other fields

- **Port ranges.** A port's `range` names the range its host port comes
  from, as in Agones. The `default` range is 7000 to 8000 unless
  `--min-port` and `--max-port` say otherwise; the others are given with
  `--additional-port-ranges`, in the JSON the Agones controller's flag of
  that name takes (`{"game": [5000, 6000]}`). Agones has one such setting
  for the cluster; scrim has one for each machine, so machines may differ.
  The ranges of a machine must not overlap. A GameServer that names a range
  no machine has waits for one, and its events say which range.
- **Static ports** must give their `hostPort`. Two Static ports on the same
  host port and protocol are refused when the manifest is applied; on
  Kubernetes it is the Pod that fails later.
- **Development GameServers** (the `agones.dev/dev-address` annotation)
  are registered as in Agones: nothing is run, and the GameServer is Ready
  at the address of the annotation, on its Static ports, to be allocated
  like any other. Unlike Agones, it is Ready as soon as it is created,
  without passing through Creating, and its `status.nodeName` stays empty,
  since no machine runs it. A Fleet whose template has the annotation is
  refused. There is no out-of-cluster SDK server: the game on the
  developer's machine talks to the Agones SDK server in local mode
  (`--local`).
- **FleetAutoscaler.** The Buffer, Counter, List, Webhook, Schedule and Chain
  policies work. Wasm does not. A Webhook needs a `url` (there are no
  Kubernetes Services to name), and it must be an http or https URL. A
  Chain needs at least one entry.
- **`immutableReplicas`**, a field that the Agones CRD adds to a GameServer
  for a Kubernetes Scale, does not exist.

### After a manifest is applied

- Of a **GameServer**, only the labels and annotations can be changed:
  `scrim label` and `scrim annotate` work as `kubectl label` and `kubectl
  annotate` do, and the API takes a JSON merge patch of them. The keys that
  are not named stay, those the game server set through the SDK among them.
  The annotations under `scrim/` are scrim's and cannot be changed.
  Applying a GameServer that exists again answers that it already exists:
  its spec is what its containers were made from.
- A **Fleet** or a **FleetAutoscaler** applied again is replaced by the
  manifest, and keeps its status. `scrim scale fleet` changes the size of a
  Fleet.
- A **GameServerSet** is made by its Fleet, and is read-only.
- A **rolling update** is worked out as in v1.62, with three changes. Agones
  has the first two behind its Alpha gate `RollingUpdateSurge`, and the
  third on its main branch.
  - The old GameServerSets count with the larger of their size and what
    they have, so the Fleet stays within `maxSurge` while one of them is
    short of its size.
  - While the Fleet is over its size, the new GameServerSet is not made
    smaller: a Fleet made smaller in the middle of an update keeps its new
    GameServers.
  - An old GameServerSet that holds as many sessions as its size, or more,
    is scaled to 0 at once, instead of waiting at its size until the
    sessions end. The comparison with Agones in CI shows this one, and
    names it.

## A matchmaker

The Allocation API is the one of the Agones allocator service: the same gRPC
service and the same `POST /gameserverallocation`, so the generated Agones
clients work.

| | Agones | scrim |
|---|---|---|
| Where | the `agones-allocator` Service, port 443 | `scrim server --allocation-listen`, `127.0.0.1:9444` by default; one port for gRPC and REST |
| Server certificate | the allocator's own, from the `allocator-tls` Secret | signed by scrim's own CA, `scrim-data/tls/ca.crt` |
| Who may allocate | a client certificate, required | a bearer token (`scrim token show allocator`), or a client certificate from a CA in `--allocation-client-ca-dir` |
| Nothing to allocate | HTTP 429 and `ResourceExhausted`, which `httpUnallocatedStatusCode` can change | HTTP 429 and `ResourceExhausted`, always |
| Across clusters (`multiClusterSetting`) | allocates from other clusters | `Unimplemented` (HTTP 501) |
| A label value in `metadata` that is not valid | HTTP 500 | HTTP 400 and `InvalidArgument` |
| The store cannot keep up (its file more than a second behind) | | HTTP 503 and `Unavailable`, at once: try again |
| A request that loses the race for a game server five times | | HTTP 409 and `Aborted`: try again |

A matchmaker may name its request with the annotation
`scrim/allocation-key` in `metadata.annotations`. A request that comes again
with the same key, after a timeout for example, is given the same game
server, not a second one. Agones keeps the annotation and does nothing else
with it.

## An operator

| | Agones | scrim |
|---|---|---|
| Tools | `kubectl`, Helm | the `scrim` CLI: `apply`, `get` (also `-w`, `-o json\|yaml`), `describe`, `delete`, `scale`, `label`, `annotate`, `logs`, `allocate`, `node`, `token` |
| The API | the Kubernetes API | a REST API of its own under `/v1`; `kubectl` and client-go do not work with it |
| Namespaces | Kubernetes Namespaces | any valid name; there is nothing to create first |
| Events | Kubernetes Events | an event history of its own, kept for a day, shown by `scrim describe` |
| Machines | Kubernetes Nodes | scrim Nodes (`scrim get nodes`), with `cordon`, `drain` and `delete` |
| A game server's address | the Node's address | the agent's `--address`, as `status.address` and one `ExternalIP` in `status.addresses` |
| A machine that stops answering | Kubernetes evicts its Pods, after 5 minutes by default | its idle game servers are replaced after 5 minutes, its Allocated ones given up after 24 hours (`--node-lost-grace`, `--node-lost-allocated-grace`) |
| Metrics | the controller's `/metrics` | `--metrics-listen`, `127.0.0.1:9446` by default |

The metrics keep the names and labels of Agones (`agones_gameservers_count`,
`agones_fleets_replicas_count`, `agones_gameserver_allocations_duration_seconds`
and the others), so dashboards made for them mostly work. There are no
Kubernetes client metrics and no PlayerTracking metrics, and three of
scrim's own tell how far its file is behind (`scrim_store_*`).

scrim writes two annotations of its own on GameServers,
`scrim/last-request` and `scrim/last-counts-change`, for its own
bookkeeping. Nothing should depend on them.

## Moving from Agones to scrim

1. **The game server image** stays as it is.
2. **Install scrim** on one machine and start the control plane with
   `scrim server`. Further machines join with `scrim agent` and the join
   token (see the README).
3. **Apply the manifests** with `scrim apply -f`. What scrim cannot honour is
   refused with the path of the field, and what it ignores comes back as a
   warning. Fields that usually need a change: `initContainers`, volumes
   from a ConfigMap or a Secret, and `env[].valueFrom`. The additional port
   ranges of the Agones installation (`gameservers.additionalPortRanges` in
   its Helm chart) go to each machine as `--additional-port-ranges`.
4. **Registry credentials** move from `imagePullSecrets` to `docker login`
   on each machine. scrim reads what `docker login` writes into the Docker
   configuration file; a credential helper (`credsStore`, `credHelpers`)
   is not run, and an image behind one is pulled without credentials.
5. **The matchmaker** is pointed at the allocation address of scrim, and
   told to trust `scrim-data/tls/ca.crt`. It can keep its client
   certificate when the CA that signed it is put in
   `--allocation-client-ca-dir`, or send the allocator token instead.
6. **Monitoring** scrapes `--metrics-listen`.

## Moving from scrim to Agones

1. **Manifests.** scrim runs the defaulting and validation of Agones, and
   its own checks are stricter than the CRD's, so what scrim accepted is
   meant to be accepted by Agones too. Create the namespaces first.
2. **The matchmaker** needs a client certificate for the Agones allocator,
   if it used a token with scrim, and the address of the `agones-allocator`
   Service.
3. **Requests named with `scrim/allocation-key`** lose that meaning: a
   request asked again after a timeout can be given a second game server.
4. **Images from a private registry** need `imagePullSecrets`.
5. **Port ranges** become one setting for the cluster: the default range is
   the controller's `--min-port` and `--max-port` (`gameservers.minPort`
   and `gameservers.maxPort` in the Helm chart), and the others go to
   `gameservers.additionalPortRanges`.
6. **Day-to-day operation** moves to `kubectl`: `scrim scale fleet` becomes
   `kubectl scale fleet`, `scrim label` and `scrim annotate` become
   `kubectl label` and `kubectl annotate`, `scrim describe` becomes
   `kubectl describe`, and `scrim logs` becomes `kubectl logs`.

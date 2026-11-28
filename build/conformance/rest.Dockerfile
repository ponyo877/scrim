# The REST and WebSocket conformance clients of Agones (test/sdk/restapi
# and test/sdk/websocket-watch), unchanged. Agones runs them one after the
# other against one SDK server; rest.sh says in which order they run here,
# and why.
FROM golang:1.27.3 AS build
ARG agones=third_party/agones
WORKDIR /agones
COPY ${agones}/go.mod ${agones}/go.sum ./
COPY ${agones}/vendor vendor
COPY ${agones}/pkg pkg
COPY ${agones}/test/sdk/restapi test/sdk/restapi
COPY ${agones}/test/sdk/websocket-watch test/sdk/websocket-watch
RUN CGO_ENABLED=0 go build -mod=vendor -o /rest ./test/sdk/restapi && \
    CGO_ENABLED=0 go build -mod=vendor -o /websocket ./test/sdk/websocket-watch

FROM busybox:1.38.0
COPY --from=build /rest /websocket /
COPY build/conformance/rest.sh /
ENTRYPOINT ["/rest.sh"]

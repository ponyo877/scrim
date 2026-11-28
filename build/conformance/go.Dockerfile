# The Go SDK's conformance client of Agones (test/sdk/go), unchanged.
FROM golang:1.27.3 AS build
ARG agones=third_party/agones
WORKDIR /agones
COPY ${agones}/go.mod ${agones}/go.sum ./
COPY ${agones}/vendor vendor
COPY ${agones}/pkg pkg
COPY ${agones}/sdks/go sdks/go
COPY ${agones}/test/sdk/go test/sdk/go
RUN CGO_ENABLED=0 go build -mod=vendor -o /client ./test/sdk/go

FROM scratch
COPY --from=build /client /client
ENTRYPOINT ["/client"]

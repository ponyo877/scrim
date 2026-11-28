# The Node.js SDK's conformance client of Agones (test/sdk/nodejs),
# unchanged. It takes the SDK from ../../../sdks/nodejs, so the two keep
# their places in the tree. npm only links the SDK there, so the SDK's own
# packages go into its directory first, as its package-lock.json has them.
FROM node:20.20.2-slim
ARG agones=third_party/agones
WORKDIR /agones
COPY ${agones}/sdks/nodejs sdks/nodejs
COPY ${agones}/test/sdk/nodejs test/sdk/nodejs
RUN cd sdks/nodejs && npm ci --omit=dev --no-audit --no-fund
RUN cd test/sdk/nodejs && npm install --omit=dev --no-audit --no-fund
WORKDIR /agones/test/sdk/nodejs
ENTRYPOINT ["npm", "run", "testSDK"]

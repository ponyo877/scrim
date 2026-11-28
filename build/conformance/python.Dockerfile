# The Python SDK's conformance client of Agones (test/sdk/python),
# unchanged. It finds the SDK at ../../../sdks/python, so the two keep
# their places in the tree. The packages are those of the SDK's
# pyproject.toml, at the versions it pins.
FROM python:3.15.1-slim
ARG agones=third_party/agones
WORKDIR /agones
RUN pip install --no-cache-dir grpcio==1.80.0 protobuf==6.33.6
COPY ${agones}/sdks/python sdks/python
COPY ${agones}/test/sdk/python test/sdk/python
ENTRYPOINT ["python3", "test/sdk/python/testSDKClient.py"]

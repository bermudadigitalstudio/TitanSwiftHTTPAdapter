FROM swift:4.0

WORKDIR /code

# PREBUILD DEPENDENCIES (Optional)
#
# Use the following procedure to compile your dependencies and cache them in
# a separate docker layer.

# Uncomment the following to create 'dummy' targets
# These must match your 'Package.swift' target definition exactly.
RUN mkdir /code/Sources \
  /code/Tests \
  /code/Sources/TitanSwiftHTTPAdapter \
  /code/Tests/TitanSwiftHTTPAdapterTests \
  && find /code/Sources/* -type d -exec sh -c 'touch "$0/main.swift"' {} \;

COPY Package.swift Package.resolved /code/
RUN swift build --enable-prefetching || true

RUN rm -r /code/Sources 
COPY ./Sources /code/Sources
RUN swift build

RUN rm -r /code/Tests
COPY ./Tests /code/Tests
CMD swift test

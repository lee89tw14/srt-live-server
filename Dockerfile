FROM alpine:3.24 AS builder

WORKDIR /tmp

# Install required packages
RUN apk add --no-cache linux-headers alpine-sdk cmake tcl openssl-dev zlib-dev sqlite-dev

# Clone, build and install SRT with the SRTLA patches, pinned to one commit
ARG SRT_REPO=https://github.com/lee89tw14/srt.git
ARG SRT_REF=3a5cd1aab55e5e73f98046372df33e3a73adfce7
RUN git clone ${SRT_REPO} srt \
    && cd srt \
    && git checkout ${SRT_REF} \
    && ./configure \
    && make -j$(nproc) \
    && make install

# Clone and build SRT Live Server
COPY . /tmp/srt-live-server
RUN cd srt-live-server \
    && make -j$(nproc)

# Runtime image
FROM alpine:3.24

ENV LD_LIBRARY_PATH=/lib:/usr/lib:/usr/local/lib64

# Install runtime dependencies: only the shared libraries sls and libsrt link against
RUN apk upgrade --no-cache \
    && apk add --no-cache libstdc++ libcrypto3 sqlite-libs zlib

# Copy binaries from the builder stage
COPY --from=builder /tmp/srt-live-server/bin /usr/local/bin
COPY --from=builder /usr/local/bin/srt-* /usr/local/bin
COPY --from=builder /usr/local/lib/libsrt* /usr/local/lib

# copy configuration files
COPY sls.conf /etc/sls/

# Create necessary directories with proper permissions
RUN mkdir -p /etc/sls /var/lib/sls /tmp/sls && \
    chmod 755 /etc/sls /var/lib/sls /tmp/sls && \
    chmod 666 /etc/sls/sls.conf

# expose ports
# Publisher port, Player port, HTTP API port
EXPOSE 4000/udp
EXPOSE 4001/udp
EXPOSE 8080/tcp

# run the server
CMD ["/usr/local/bin/sls", "-c", "/etc/sls/sls.conf"]

# Build environment for the PocketCHIP UBI images.
#
# The CHIP's MLC NAND needs NTC's fork of mtd-utils (ubinize -M dist3); the
# upstream tools cannot produce a bootable image. The fork is pinned to a commit.
FROM debian:bookworm-slim

ARG MTD_UTILS_REPO=https://github.com/ntc-chip-revived/CHIP-mtd-utils.git
ARG MTD_UTILS_COMMIT=f6a16e575091ef315b147532ba818877fd2c1895

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        build-essential ca-certificates git pkg-config \
        libacl1-dev liblzo2-dev uuid-dev zlib1g-dev \
        android-sdk-libsparse-utils \
 && rm -rf /var/lib/apt/lists/*

RUN git clone "$MTD_UTILS_REPO" /src/mtd-utils \
 && cd /src/mtd-utils \
 && git checkout "$MTD_UTILS_COMMIT" \
 && make WITHOUT_XATTR=1 CFLAGS="-O2 -Wno-error -fcommon -include sys/sysmacros.h" \
 && find . -maxdepth 2 -type f \( -name mkfs.ubifs -o -name ubinize \) -perm -u+x \
        -exec install -m 0755 {} /usr/local/bin/ \;

COPY make-ubi.sh /usr/local/bin/make-ubi.sh
ENTRYPOINT ["/usr/local/bin/make-ubi.sh"]

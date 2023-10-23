FROM aswf/ci-base:2023.1 as build-stage

# NOTE: Most of the RUN steps have been split out in order to
# take advantage of Docker's built-in caching mechanism.

# Bash utils useful for debugging
RUN alias ll='ls -hl'
RUN yum update -y && yum install tree -y

# for pyenv
ARG PYTHON_VERSION_FULL=3.9.10
# for pybind11
ARG PYTHON_VERSION_SHORT=3.9

# In order not to depend on the outer internet, this Dockerfile tries to only
# rely on local files. This means that before running it, you will need to
# have downloaded all of the tarballs required to compile the various
# dependencies (see the `download_tarballs.sh` script).
ARG TARBALLS_ROOT=/opt/tarballs
WORKDIR ${TARBALLS_ROOT}
COPY tarballs ${TARBALLS_ROOT}

# Compile ZLIB
ARG ZLIB_ROOT=/opt/zlib
WORKDIR ${ZLIB_ROOT}
RUN cp ${TARBALLS_ROOT}/zlib-1.3.tar.gz . \
    && tar -xvf zlib-1.3.tar.gz \
    && cd zlib-1.3 \
    && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${ZLIB_ROOT} \
    && cmake --build build --config Release --target install

# Compile OpenEXR
ARG OPENEXR_ROOT=/opt/openexr
WORKDIR ${OPENEXR_ROOT}

RUN cp ${TARBALLS_ROOT}/OpenEXR_v2.4.15.0.tar.gz . \
    && tar -xvf OpenEXR_* \
    && mv openexr-*/* . \
    && mv openexr-*/.[!.]* .
RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${OPENEXR_ROOT}/dist \
    -DBUILD_TESTING=OFF -DBUILD_SHARED_LIBS=OFF -DOPENEXR_BUILD_TOOLS=OFF \
    -DOPENEXR_INSTALL_TOOLS=OFF -DOPENEXR_INSTALL_EXAMPLES=OFF \
    && cmake --build build --target install --config Release

# Compile Boost
ARG BOOST_ROOT=/opt/boost
WORKDIR ${BOOST_ROOT}/download
RUN cp ${TARBALLS_ROOT}/boost_1_81_0.tar.bz2 . \
    && tar --bzip2 -xvf boost_1_81_0.tar.bz2
RUN cd boost_1_81_0 \
    && ./bootstrap.sh --prefix=${BOOST_ROOT} \
    && ./b2 install \
    && rm -rf ${BOOST_ROOT}/download

# libtiff
ARG TIFF_ROOT=/opt/tiff
WORKDIR ${TIFF_ROOT}/download
RUN cp ${TARBALLS_ROOT}/tiff-4.0.10.tar.gz . \
    && tar -xvf tiff-4.0.10.tar.gz
RUN cd tiff-4.0.10 \
    && ./configure --prefix=${TIFF_ROOT} \
    && cmake -S . -B build \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=${TIFF_ROOT} \
    && cd build \
    && make \
    && make install

# libraw
ARG LIBRAW_ROOT=/opt/libraw
WORKDIR ${LIBRAW_ROOT}/download
RUN cp ${TARBALLS_ROOT}/LibRaw-0.21.1.tar.gz . \
    && tar -xvf LibRaw-0.21.1.tar.gz
RUN cd LibRaw-0.21.1 \
    && autoreconf -fiv \
    && ./configure --prefix /opt/libraw \
    && make install \
    && cd ../.. && rm -rf download

# OpenColorIO tar build
ARG OpenColorIO_ROOT=/opt/OpenColorIO
ARG OpenColorIO_BUILD_ROOT=/opt/OpenColorIO/dist
ARG OPENCOLORIO_BUILDOPTS="-DOCIO_BUILD_APPS=OFF -DOCIO_BUILD_NUKE=OFF \
                           -DOCIO_BUILD_DOCS=OFF -DOCIO_BUILD_TESTS=OFF \
                           -DOCIO_BUILD_GPU_TESTS=OFF \
                           -DOCIO_BUILD_PYTHON=OFF -DOCIO_BUILD_PYGLUE=OFF \
                           -DOCIO_BUILD_JAVA=OFF \
                           -DBUILD_SHARED_LIBS=ON"
WORKDIR ${OpenColorIO_ROOT}
RUN cp ${TARBALLS_ROOT}/OpenColorIO_v2.3.0.tar.gz . \
    && tar -xvf OpenColorIO_v2.3.0.tar.gz
RUN cd OpenColorIO-2.3.0 \
    && mkdir build \
    && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Release \
           -DCMAKE_INSTALL_PREFIX=${OpenColorIO_BUILD_ROOT} \
           -DCMAKE_CXX_FLAGS="-Wno-unused-function -Wno-deprecated-declarations -Wno-cast-qual -Wno-write-strings" \
           ${OPENCOLORIO_BUILDOPTS} ${OpenColorIO_ROOT}/OpenColorIO-2.3.0 \
    && cmake --build . --config Release --target install
# Fix weird syntax error that occurs from build
RUN sed -i "s;.\#define ZLIB_VERSION \"1.3\"; ;g" ${OpenColorIO_BUILD_ROOT}/lib64/cmake/OpenColorIO/OpenColorIOConfig.cmake


# Install specific python
ENV PYENV_ROOT=/opt/pyenv
RUN git clone https://github.com/pyenv/pyenv.git ${PYENV_ROOT}
ENV PATH ${PYENV_ROOT}/shims:${PYENV_ROOT}/bin:${PATH}

RUN pyenv install ${PYTHON_VERSION_FULL}
RUN pyenv global ${PYTHON_VERSION_FULL}
RUN pyenv rehash

ARG OIIO_ROOT=/opt/OpenImageIO
WORKDIR ${OIIO_ROOT}

RUN cp ${TARBALLS_ROOT}/OpenImageIO_v2.4.15.0.tar.gz . \
    && tar -xvf OpenImageIO_v2.4.15.0.tar.gz
WORKDIR ${OIIO_ROOT}/OpenImageIO-2.4.15.0

# Compile libjpeg-turbo
# TODO: Use a tarball here too
# https://github.com/libjpeg-turbo/libjpeg-turbo/blob/main/BUILDING.md
ARG JPEGTurbo_ROOT=/opt/OpenImageIO/OpenImageIO-2.4.15.0/src/build-scripts/ext/dist
RUN cd src/build-scripts \
    && ./build_libjpeg-turbo.bash

# Compile OpenColorIO
#ARG OpenColorIO_ROOT=/opt/OpenImageIO/OpenImageIO-2.4.15.0/src/build-scripts/ext/dist
#RUN cd src/build-scripts \
#    && ./build_opencolorio.bash
# Fix weird syntax error that occurs from build
#RUN sed -i "s;.\#define ZLIB_VERSION \"1.3\"; ;g" ${OpenColorIO_ROOT}/lib64/cmake/OpenColorIO/OpenColorIOConfig.cmake

# Compile pybind11
ENV PYBIND11_PYTHON_VERSION ${PYTHON_VERSION_SHORT}
ENV PYTHON_VERSION ${PYTHON_VERSION_SHORT}

RUN cd src/build-scripts \
    && ./build_pybind11.bash

# Copy and compile OpenImageIO
RUN which python \
    pwd \
    && tree -L 2 -d \
    && make -j $(nproc) USE_PYTHON=1 USE_TBB=0 USE_NUKE=0 BUILD_SHARED_LIBS=1 USE_QT=0 \
    Boost_ROOT=${BOOST_ROOT} \
    ZLIB_ROOT=${ZLIB_ROOT}/build \
    LibRaw_ROOT=${LIBRAW_ROOT} \
    TIFF_ROOT=${TIFF_ROOT} \
    OpenEXR_ROOT=${OPENEXR_ROOT}/dist \
    OpenColorIO_ROOT=${OpenColorIO_BUILD_ROOT} \
    JPEGTurbo_ROOT=${JPEGTurbo_ROOT} \
    Imath_DIR=${OPENEXR_ROOT}/dist/lib64/cmake/Imath

# Create a tarball of the OIIO build
ARG OIIO_DIST_ROOT=/opt/oiio-dist
ARG OIIO_TARBALL_NAME=oiio-dist.tar.gz
WORKDIR ${OIIO_DIST_ROOT}

# CLI used to update the RUNPATH
RUN yum install patchelf -y

# Copy all the .so files needed by OIIO, except for the ones
# that should be installed on the system (so in /usr and /lib)
RUN ldd ${OIIO_ROOT}/OpenImageIO-2.4.15.0/dist/lib64/libOpenImageIO.so \
    | awk '{ print $3 }' | tr -s '\n' \
    | grep '/opt' \
    > libs_to_copy.txt \
    && mkdir third-party-libs \
    && xargs -a libs_to_copy.txt cp -t third-party-libs \
    && cp ${OIIO_ROOT}/OpenImageIO-2.4.15.0/src/build-scripts/ext/dist/lib64/*.so.* third-party-libs

# Flatten all of the libs into the lib64 directory
# and patch their RPATH
RUN cp -r ${OIIO_ROOT}/OpenImageIO-2.4.15.0/dist . \
    && mv third-party-libs/* dist/lib64 \
    && rm -rf dist/lib64/cmake \
    && rm -rf dist/lib64/pkgconfig \
    && rmdir third-party-libs \
    && patchelf --set-rpath '$ORIGIN' $(find dist/lib64/ -maxdepth 1 -type f)

# Patch the binaries
RUN patchelf --set-rpath '$ORIGIN/../lib64' dist/bin/*

# Make a final single tarball
RUN tar -czf ${OIIO_TARBALL_NAME} dist \
    && rm -rf ./dist \
    && rm libs_to_copy.txt

FROM scratch as export-stage
COPY --from=build-stage /opt/oiio-dist/oiio-dist.tar.gz .

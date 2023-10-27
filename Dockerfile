FROM aswf/ci-base:2023.1 as build-stage

# NOTE: Most of the RUN steps have been split out in order to
# take advantage of Docker's built-in caching mechanism.

# Bash utils useful for debugging
RUN alias ll='ls -hl'
RUN yum update -y && yum install tree -y

# TODO: move to separate config file
# Notes on variable names:
# PYENV_VERSION is reserved by pyenv for python version to use
# PYTHON_VERSION is reserved by pybind11 for python version to build for (set latter)

# for pyenv
ARG PYTHON_PYENV_VERSION=2.3.31
ARG PYTHON_VERSION_FULL=3.9.10
# for pybind11
ARG PYTHON_VERSION_SHORT=3.9

# Dependency Versions
ARG LIBJPEGTURBO_VERSION=3.0.0
ARG LIBTIFF_VERION=4.0.10
ARG LIBRAW_VERSION=0.21.1
ARG ZLIB_VERSION=1.3
ARG PYBIND11_VERSION=2.11.1
ARG BOOST_VERSION=1_81_0
ARG OPENEXR_VERSION=2.4.15.0
ARG OPENCOLORIO_VERSION=2.3.0
ARG OPENIMAGEIO_VESION=2.4.15.0
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
RUN cp ${TARBALLS_ROOT}/zlib-${ZLIB_VERSION}.tar.gz . \
    && tar -xvf zlib-${ZLIB_VERSION}.tar.gz \
    && cd zlib-${ZLIB_VERSION} \
    && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${ZLIB_ROOT} \
    && cmake --build build --config Release --target install

# Compile OpenEXR
ARG OPENEXR_ROOT=/opt/openexr
WORKDIR ${OPENEXR_ROOT}
RUN cp ${TARBALLS_ROOT}/OpenEXR_v${OPENEXR_VERSION}.tar.gz . \
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
RUN cp ${TARBALLS_ROOT}/boost_${BOOST_VERSION}.tar.bz2 . \
    && tar --bzip2 -xvf boost_${BOOST_VERSION}.tar.bz2
RUN cd boost_${BOOST_VERSION} \
    && ./bootstrap.sh --prefix=${BOOST_ROOT} \
    && ./b2 install \
    && rm -rf ${BOOST_ROOT}/download

# libtiff
ARG TIFF_ROOT=/opt/tiff
WORKDIR ${TIFF_ROOT}/download
RUN cp ${TARBALLS_ROOT}/tiff-${LIBTIFF_VERION}.tar.gz . \
    && tar -xvf tiff-${LIBTIFF_VERION}.tar.gz
RUN cd tiff-${LIBTIFF_VERION} \
    && ./configure --prefix=${TIFF_ROOT} \
    && cmake -S . -B build \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=${TIFF_ROOT} \
    && cd build \
    && make \
    && make install

# libraw
ARG LIBRAW_ROOT=/opt/libraw
WORKDIR ${LIBRAW_ROOT}/download
RUN cp ${TARBALLS_ROOT}/LibRaw-${LIBRAW_VERSION}.tar.gz . \
    && tar -xvf LibRaw-${LIBRAW_VERSION}.tar.gz
RUN cd LibRaw-${LIBRAW_VERSION} \
    && autoreconf -fiv \
    && ./configure --prefix /opt/libraw \
    && make install \
    && cd ../.. && rm -rf download

# OpenColorIO tar build
ARG OpenColorIO_ROOT=/opt/OpenColorIO
ARG OpenColorIO_INSTALL_DIR=${OpenColorIO_ROOT}/dist
WORKDIR ${OpenColorIO_ROOT}
RUN cp ${TARBALLS_ROOT}/OpenColorIO_v${OPENCOLORIO_VERSION}.tar.gz . \
    && tar -xvf OpenColorIO_v${OPENCOLORIO_VERSION}.tar.gz
RUN cd OpenColorIO-${OPENCOLORIO_VERSION} \
    && mkdir build \
    && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Release \
             -DCMAKE_INSTALL_PREFIX=${OpenColorIO_INSTALL_DIR} \
             -DCMAKE_CXX_FLAGS="-Wno-unused-function -Wno-deprecated-declarations -Wno-cast-qual -Wno-write-strings" \
             -DOCIO_BUILD_APPS=OFF -DOCIO_BUILD_NUKE=OFF \
             -DOCIO_BUILD_DOCS=OFF -DOCIO_BUILD_TESTS=OFF \
             -DOCIO_BUILD_GPU_TESTS=OFF \
             -DOCIO_BUILD_PYTHON=OFF -DOCIO_BUILD_PYGLUE=OFF \
             -DOCIO_BUILD_JAVA=OFF \
             -DBUILD_SHARED_LIBS=ON \
             .. \
    && cmake --build . --config Release --target install
# Fix weird syntax error that occurs from build
# Uncertain if $ZLIB_VERSION will match the version OCIO uses. Originally the OCIO build here uses 1.3
RUN sed -i "s;.\#define ZLIB_VERSION \"${ZLIB_VERSION}\"; ;g" ${OpenColorIO_INSTALL_DIR}/lib64/cmake/OpenColorIO/OpenColorIOConfig.cmake


# Install specific python
ARG PYENV_BASE_DIR=/opt/pyenv
WORKDIR ${PYENV_BASE_DIR}
RUN cp ${TARBALLS_ROOT}/pyenv-${PYTHON_PYENV_VERSION}.tar.gz . \
    && tar -xvf pyenv-${PYTHON_PYENV_VERSION}.tar.gz \
    && mkdir pyenv-${PYTHON_PYENV_VERSION}/cache \
    && cp ${TARBALLS_ROOT}/Python-${PYTHON_VERSION_FULL}.tar.xz pyenv-${PYTHON_PYENV_VERSION}/cache/
ENV PYENV_ROOT=${PYENV_BASE_DIR}/pyenv-${PYTHON_PYENV_VERSION}
# python versions are defined per pyenv
ENV PATH ${PYENV_ROOT}/shims:${PYENV_ROOT}/bin:${PATH}
RUN pyenv install ${PYTHON_VERSION_FULL}
RUN pyenv global ${PYTHON_VERSION_FULL}
RUN pyenv rehash

# Compile libjpeg-turbo
ARG JPEGTurbo_ROOT=/opt/libjpeg-turbo
ARG LIBJPEGTURBO_INSTALL_DIR=${JPEGTurbo_ROOT}/dist
WORKDIR ${JPEGTurbo_ROOT}
RUN cp ${TARBALLS_ROOT}/libjpeg-turbo_v${LIBJPEGTURBO_VERSION}.tar.gz . \
    && tar -xvf libjpeg-*
RUN cd libjpeg-turbo-${LIBJPEGTURBO_VERSION} \
    && mkdir build \
    && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Release \
             -DCMAKE_INSTALL_PREFIX=${LIBJPEGTURBO_INSTALL_DIR} \
             .. \
    && cmake --build . --config Release --target install

# Compile pybind11
ENV PYBIND11_PYTHON_VERSION ${PYTHON_VERSION_SHORT}
ENV PYTHON_VERSION ${PYTHON_VERSION_SHORT}
ARG PYBIND11_ROOT=/opt/pybind11
ARG PYBIND11_INSTALL_DIR=/opt/pybind11/dist
WORKDIR ${PYBIND11_ROOT}
RUN cp ${TARBALLS_ROOT}/pybind11-${PYBIND11_VERSION}.tar.gz . \
    && tree -L 2 -d \
    && tar -xvf pybind11-*
RUN  cd pybind11-${PYBIND11_VERSION} \
    && mkdir build \
    && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Release \
             -DCMAKE_INSTALL_PREFIX=${PYBIND11_INSTALL_DIR} \
             -DPYBIND11_TEST=OFF \
             -DPYBIND11_PYTHON_VERSION=${PYTHON_VERSION}  \
             .. \
    && cmake --build . --config Release --target install

# Copy and compile OpenImageIO
ARG OIIO_ROOT=/opt/OpenImageIO
WORKDIR ${OIIO_ROOT}
RUN cp ${TARBALLS_ROOT}/OpenImageIO_v${OPENIMAGEIO_VESION}.tar.gz . \
    && tar -xvf OpenImageIO_v${OPENIMAGEIO_VESION}.tar.gz
RUN cd OpenImageIO-${OPENIMAGEIO_VESION} \
    && tree -L 2 -d \
    && make -j $(nproc) USE_PYTHON=1 USE_TBB=0 USE_NUKE=0 BUILD_SHARED_LIBS=1 USE_QT=0 \
    Boost_ROOT=${BOOST_ROOT} \
    ZLIB_ROOT=${ZLIB_ROOT}/build \
    LibRaw_ROOT=${LIBRAW_ROOT} \
    TIFF_ROOT=${TIFF_ROOT} \
    OpenEXR_ROOT=${OPENEXR_ROOT}/dist \
    OpenColorIO_ROOT=${OpenColorIO_INSTALL_DIR} \
    JPEGTurbo_ROOT=${LIBJPEGTURBO_INSTALL_DIR} \
    Imath_DIR=${OPENEXR_ROOT}/dist/lib64/cmake/Imath

# Create a tarball of the OIIO build
ARG OIIO_DIST_ROOT=/opt/oiio-dist
ARG OIIO_TARBALL_NAME=oiio-dist.tar.gz
WORKDIR ${OIIO_DIST_ROOT}

# CLI used to update the RUNPATH
RUN yum install patchelf -y

# Copy all the .so files needed by OIIO, except for the ones
# that should be installed on the system (so in /usr and /lib)
RUN ldd ${OIIO_ROOT}/OpenImageIO-${OPENIMAGEIO_VESION}/dist/lib64/libOpenImageIO.so \
    | awk '{ print $3 }' | tr -s '\n' \
    | grep '/opt' \
    > libs_to_copy.txt \
    && mkdir third-party-libs \
    && xargs -a libs_to_copy.txt cp -t third-party-libs \
    && cp ${LIBJPEGTURBO_INSTALL_DIR}/lib64/*.so.* third-party-libs

# Flatten all of the libs into the lib64 directory
# and patch their RPATH
RUN cp -r ${OIIO_ROOT}/OpenImageIO-${OPENIMAGEIO_VESION}/dist . \
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

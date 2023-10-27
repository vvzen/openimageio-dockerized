#!/bin/bash

set -e

mkdir -p tarballs
cd tarballs

# TODO: add sha256 checks for every tarball
# TODO: add tarball support for fmtlib & Tessil (downloaded automatically by OIIO)

# Boost
[ ! -f boost_1_81_0.tar.bz2 ] && wget https://boostorg.jfrog.io/artifactory/main/release/1.81.0/source/boost_1_81_0.tar.bz2
# libjpeg-turbo
[ ! -f libjpeg-turbo_v3.0.0.tar.gz ] && wget https://github.com/libjpeg-turbo/libjpeg-turbo/archive/refs/tags/3.0.0.tar.gz -O libjpeg-turbo_v3.0.0.tar.gz
# libtiff
[ ! -f tiff-4.0.10.tar.gz ] && wget https://download.osgeo.org/libtiff/tiff-4.0.10.tar.gz
# LibRaw
[ ! -f LibRaw-0.21.1.tar.gz ] && wget https://www.libraw.org/data/LibRaw-0.21.1.tar.gz
# OpenEXR
[ ! -f OpenEXR_v2.4.15.0.tar.gz ] && wget https://github.com/AcademySoftwareFoundation/openexr/archive/refs/tags/v3.2.1.tar.gz -O OpenEXR_v2.4.15.0.tar.gz
# OpenImageIO
[ ! -f OpenImageIO_v2.4.15.0.tar.gz ] && wget https://github.com/AcademySoftwareFoundation/OpenImageIO/archive/refs/tags/v2.4.15.0.tar.gz -O OpenImageIO_v2.4.15.0.tar.gz
# OpenColorIO
[ ! -f OpenColorIO_v2.3.0.tar.gz ] && wget https://github.com/AcademySoftwareFoundation/OpenColorIO/archive/refs/tags/v2.3.0.tar.gz -O OpenColorIO_v2.3.0.tar.gz
# Zlib
[ ! -f zlib-1.3.tar.gz ] && wget https://github.com/madler/zlib/releases/download/v1.3/zlib-1.3.tar.gz
# pybind11
[ ! -f pybind11-2.11.1.tar.gz ] && wget https://github.com/pybind/pybind11/archive/refs/tags/v2.11.1.tar.gz -O pybind11-2.11.1.tar.gz
# pyenv
[ ! -f pyenv-2.3.31.tar.gz ] && wget https://github.com/pyenv/pyenv/archive/refs/tags/v2.3.31.tar.gz -O pyenv-2.3.31.tar.gz
# python for pyenv
# Make sure the downloaded version of pyenv supports the downloaded version of python.
[ ! -f Python-3.9.10.tar.xz ] && wget https://www.python.org/ftp/python/3.9.10/Python-3.9.10.tar.xz


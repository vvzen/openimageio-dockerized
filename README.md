# README

## What problem does this repo solve

Since OpenImageIO is written in C++, the task of compiling it correctly can prove to be very boring and error prone, so I have automated most of it through Docker.

### Requirements

If you're on linux, most things should work.
If you're on macOS, I'm working on a script.
If you're on Windows, I have no idea how to make it work.

You will only need to have `docker` installed and its service active and running (on systemd distros, you can check via `sudo systemctl status docker`).

Before starting, download the tarballs containing all the dependencies needed to build OIIO:

``` shell
chmod +x ./download_tarballs.sh && ./download_tarballs.sh
```

If everything went fine, you should have this:

``` shell
$ tree tarballs
tarballs
├── boost_1_81_0.tar.bz2
├── LibRaw-0.21.1.tar.gz
├── OpenEXR_v2.4.15.0.tar.gz
├── OpenImageIO_v2.4.15.0.tar.gz
├── tiff-4.0.10.tar.gz
└── zlib-1.3.tar.gz
```

### Running the build

To perform a build of OIIO, you can do something like this:
``` shell
# Run the dockerized build of OIIO (this might take a bit)
make docker-build

# Copy the final tarball containing the final dist (libs+binaries)
make docker-export
```

This will run the whole build process inside a Docker container and finally the copy the compiled bits back to your own filesystem.
All libraries and binaries are patched so that they are easily relocatable.

The final result will be a `oiio-dist.tar.gz` tarballs whose content looks like this:
```bash
$ tar -xvf oiio-dist.tar.gz
$ tree dist -L 2 
tree dist -L 2
dist
├── bin
│   ├── iconvert
│   ├── idiff
│   ├── igrep
│   ├── iinfo
│   ├── maketx
│   ├── oiiotool
│   └── testtex
├── include
│   └── OpenImageIO
├── lib64
│   ├── libboost_atomic.so.1.81.0
│   ├── libboost_chrono.so.1.81.0
│   ├── libboost_filesystem.so.1.81.0
│   ├── libboost_thread.so.1.81.0
│   ├── libjpeg.so.62
│   ├── libjpeg.so.62.3.0
│   ├── libOpenImageIO.so -> libOpenImageIO.so.2.4
│   ├── libOpenImageIO.so.2.4 -> libOpenImageIO.so.2.4.15
│   ├── libOpenImageIO.so.2.4.15
│   ├── libOpenImageIO_Util.so -> libOpenImageIO_Util.so.2.4
│   ├── libOpenImageIO_Util.so.2.4
│   ├── libOpenImageIO_Util.so.2.4.15
│   ├── libraw_r.so.23
│   ├── libtiff.so.5
│   ├── libturbojpeg.so.0
│   └── libturbojpeg.so.0.2.0
└── share
    ├── doc
    └── fonts

8 directories, 23 files
```

Running through Docker also helps standardize the build steps so that the whole process is easily reproducible. The Dockerfile starts building using the `aswf/ci-base:2023.1` image as a base.

### How does this whole thing work?

This workflow uses a multi-stage `Dockerfile`.

There are 2 stages:
- build-stage (Build OIIO and its libraries)
- export-stage (Export the compiled bits back to your filesystem)

These stages will:
- [build-stage] Compile all third-party libraries required by OpenImageIO
  - This is done using the tarballs in the `tarballs` dir, so for most things no internet connection is required (the only things still cloned from a remote are Imath and libturbo-jpeg, and I'll fix it soon) 
- [build-stage] Compile OpenImageIO and link against these third-party libraries
- [build-stage] Copy the required share libraries (.so files) needed to use OIIO at runtime
- [build-stage] Use `patchelf` to set the RPATH of all libraries to be relative
  - This effectively makes them easy to relocate and move around
- [export-stage] Copy a tarball (`oiio-dist.tar.gz`) into your local filesystem
  - This will contain the required headers and libs and binaries

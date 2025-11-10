IMAGE_TAG=vv-oiio-build

download:
	bash download_tarballs.sh

build: download
	docker buildx build --platform linux/amd64 . -t $(IMAGE_TAG) --target build-stage

run: build
	docker run -it -t $(IMAGE_TAG) bash

export: build
	docker buildx build --platform linux/amd64 --progress=plain . -t $(IMAGE_TAG) --target export-stage --output .

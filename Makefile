IMAGE_TAG=vv-oiio-build

docker-build:
	docker build --platform linux/amd64 --progress=plain . -t $(IMAGE_TAG) --target build-stage

docker-run:
	docker run -it -t $(IMAGE_TAG) bash

docker-export:
	DOCKER_BUILDKIT=1 docker build --platform linux/amd64 --progress=plain . -t $(IMAGE_TAG) --target export-stage --output .

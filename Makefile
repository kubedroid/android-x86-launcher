docker:
	sudo docker build . -t quay.io/quamotion/android-x86-launcher:latest

run:
	sudo docker run --rm -it --entrypoint "/bin/bash" quay.io/quamotion/android-x86-launcher:latest

tag:
	sudo docker tag quay.io/quamotion/android-x86-launcher:latest docker.io/kubevirt/virt-launcher:v0.10.0

untag:
	sudo docker tag docker.io/kubevirt/virt-launcher@sha256:8f8ccfb5281916ee77792f7d92182db11f4205d523fb826c6e21e73b09a5f3a7 docker.io/kubevirt/virt-launcher:v0.10.0

docker:
	sudo docker build . -t quay.io/quamotion/android-x86-launcher:latest

run:
	sudo docker run --rm -it --entrypoint "/bin/bash" quay.io/quamotion/android-x86-launcher:latest

tag:
	sudo docker tag quay.io/quamotion/android-x86-launcher:latest docker.io/kubevirt/virt-launcher:v0.10.0

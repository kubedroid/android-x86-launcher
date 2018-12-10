docker:
	sudo docker build . -t quay.io/quamotion/android-x86-launcher:latest

run:
	sudo docker run --rm -it --entrypoint "/bin/bash" quay.io/quamotion/android-x86-launcher:latest

tag:
	sudo docker tag quay.io/quamotion/android-x86-launcher:latest docker.io/kubevirt/virt-launcher:v0.12.0-alpha.0

untag:
	sudo docker tag docker.io/kubevirt/virt-launcher@sha256:ba612dd4b4373ca3cf4073188314955d5529a76ff0a7b08cc36c74847d1f3e42 docker.io/kubevirt/virt-launcher:v0.12.0-alpha0

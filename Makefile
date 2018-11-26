docker:
	sudo docker build . -t quay.io/quamotion/android-x86-launcher:latest

run:
	sudo docker run --rm -it --entrypoint "/bin/bash" quay.io/quamotion/android-x86-launcher:latest

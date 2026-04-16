# tag for the source image agains which the catkin workspace will be built
export BASE_IMAGE=ctumrs/mrs_uav_system:1.5.1 #to change in uvdar one

# tag for the 'transport' image used for packing the workspace
export TRANSPORT_IMAGE=alpine:latest 

# tag for the resulting image in which the workspace will be packged
export OUTPUT_IMAGE=uvdar_workspace:1.0.1 #create your own image

# location for the exported docker images using the `./export_image.sh` script
export EXPORT_PATH=~/docker

# CPU architecture for the output image
export ARCH=amd64

# path to the catkin workspace in the docker image
export WORKSPACE_PATH=etc/docker/catkin_workspace_1

# local path to the build cache
export CACHE_PATH=cache

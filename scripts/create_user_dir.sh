#!/bin/bash

echo "Creating directory '$1' for user '$USER'"
sudo mkdir -p $1
sudo chown -R $USER:$USER $1
sudo chmod -R a=,a+rX,u+w,g+w $1
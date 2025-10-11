#!/bin/bash

sudo ./hadoop-stop.sh -r
sudo docker rmi szcq/hadoop:2.7.7-ha-beta
set -e
sudo docker build -t szcq/hadoop:2.7.7-ha-beta .
sudo ./hadoop-start.sh -i

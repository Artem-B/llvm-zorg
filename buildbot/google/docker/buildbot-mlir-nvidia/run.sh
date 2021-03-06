#!/bin/bash
#===-- run.sh -------------------------------------------------------------===//
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
#===----------------------------------------------------------------------===//
# This script will start the buildbot worker
#===----------------------------------------------------------------------===//

set -eu

# Read the worker password from a mounted file.
WORKER_PASSWORD=$(cat /secrets/token)

# generate the host information of this worker
( 
  uname -a ; \
  cat /proc/cpuinfo | grep "model name" | head -n1 | cut -d " " -f 3- ;\
  echo "number of cores: $(nproc)" ;\
  nvidia-smi -L | cut -d "(" -f 1 ;\
  lsb_release -d | cut -f 2- ; \
  clang --version | head -n1 ; \
  ld.lld-8 --version ; \
  cmake --version | head -n1 
) > ${WORKER_NAME}/info/host 

# It looks like GKE sometimes deploys the container before the NVIDIA drivers 
# are loaded on the host. In this case the GPU is not available during the 
# entire lifecycle of the container. Not sure how to fix this properly. 

RETURN_CODE=$(nvidia-smi > /dev/null ; echo $?)
if [[ "$RETURN_CODE" != "0" ]] ; then
  echo "ERROR: Failed to access NVIDIA graphics card."
  echo "Exiting in 30 secs..."
  sleep 30
  exit 1
fi

# create the folder structure
# port 9990 for production
# port 9994 for staging
buildslave create-slave --keepalive=200 "${WORKER_NAME}" \
  lab.llvm.org:9990 "${WORKER_NAME}" "${WORKER_PASSWORD}"

# start the daemon, this command return immetiately
buildslave start "${WORKER_NAME}"

# To keep the container running and produce log outputs: dump the worker
# log to stdout
tail -f ${WORKER_NAME}/twistd.log

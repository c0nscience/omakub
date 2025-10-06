#!/bin/bash

sudo snap install kubectl --classic
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl >/dev/null

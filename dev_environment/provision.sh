#!/usr/bin/env bash

set -eux

ssh-keyscan -H github.com >> ~/.ssh/known_hosts

# Copy grafana configs and dashboards into place
mkdir -p /var/lib/grafana/dashboards
chown grafana:grafana /var/lib/grafana/dashboards
cp /vagrant/cfg/grafana/dashboards/*.json /var/lib/grafana/dashboards
chown grafana:grafana /var/lib/grafana/dashboards/*.json
cp /vagrant/cfg/grafana/provisioning/dashboards/l3af.yaml /etc/grafana/provisioning/dashboards
chown root:grafana /etc/grafana/provisioning/dashboards/*.yaml
cp /vagrant/cfg/grafana/provisioning/datasources/l3af.yaml /etc/grafana/provisioning/datasources
chown root:grafana /etc/grafana/provisioning/datasources/*.yaml

# Copy prometheus config and restart prometheus
cp /vagrant/cfg/prometheus.yml /etc/prometheus/prometheus.yml
systemctl daemon-reload
systemctl restart prometheus prometheus-node-exporter

# Start and enable Grafana
systemctl daemon-reload
systemctl start grafana-server
systemctl enable grafana-server.service

# Get Linux source code to build our eBPF programs against
# TODO: Support building against the Linux source from the distro's source
# package.
git clone --branch v5.1 --depth 1 https://github.com/torvalds/linux.git /usr/src/linux
LINUX_SRC_DIR=/usr/src/linux
cd $LINUX_SRC_DIR
make defconfig

mkdir -p /var/log/tb/l3af

BUILD_DIR=$LINUX_SRC_DIR/samples/bpf/

# Where to store the tar.gz build artifacts
BUILD_ARTIFACT_DIR=/srv/l3afd
mkdir -p $BUILD_ARTIFACT_DIR

# declare an array variable
declare -a progs=("xdp-root" "ratelimiting" "connection-limit")

# now loop through the above array
for prog in "${progs[@]}"
do
	# Get and build the L3AF root program
	cd $BUILD_DIR
	git clone git@github.com:l3af-project/$prog.git
	cd $prog
	make
	PROG_ARTIFACT_DIR=$BUILD_ARTIFACT_DIR/$prog/latest/focal
	mkdir -p $PROG_ARTIFACT_DIR
	mv *.tar.gz $PROG_ARTIFACT_DIR
done

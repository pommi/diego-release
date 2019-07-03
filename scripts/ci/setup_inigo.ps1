$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

Write-Host "Starting setup_inigo"
$env:TMP_HOME=($pwd).path
$env:GOROOT="C:\var\vcap\packages\golang-1.12-windows\go"
$env:PATH= "$env:GOROOT/bin;$env:PATH"

# # Setup DNS for *.service.cf.internal, used by the Diego components, and
# # *.test.internal, used by the collocated DUSTs as a routable domain.
# function setup_dnsmasq() {
#   local host_addr
#   host_addr=$(ip route get 8.8.8.8 | head -n1 | awk '{print $NF}')
#
#   dnsmasq --address=/service.cf.internal/127.0.0.1 --address=/test.internal/${host_addr}
#   echo -e "nameserver $host_addr\n$(cat /etc/resolv.conf)" > /etc/resolv.conf
# }

function Kill-Garden {
  Get-Process | foreach { if ($_.name -eq "gdn") { kill -Force $_.Id } }
}

function Build-Gdn {
	param([string] $dir)
  Write-Host "Starting Build-Gdn"
  push-location $dir
  $env:GOPATH="$PWD/src/gopath"
  mkdir ./src/gopath/src/code.cloudfoundry.org -ea 0
    if (Test-Path ./src/guardian) {
      mv ./src/guardian ./src/gopath/src/code.cloudfoundry.org/
    }
  go build -o gdn.exe ./src/gopath/src/code.cloudfoundry.org/guardian/cmd/gdn
    if ($LastExitCode -ne 0) {
      throw "Building gdn.exe process returned error code: $LastExitCode"
    }

# Kill any existing garden servers
  Kill-Garden
  Write-Host "Finished Build-Gdn"
}


# create_garden_storage() {
#   # Configure cgroup
#   mount -t tmpfs cgroup_root /sys/fs/cgroup
#   mkdir -p /sys/fs/cgroup/devices
#   mkdir -p /sys/fs/cgroup/memory
#
#   mount -tcgroup -odevices cgroup:devices /sys/fs/cgroup/devices
#   devices_mount_info=$(cat /proc/self/cgroup | grep devices)
#   devices_subdir=$(echo $devices_mount_info | cut -d: -f3)
#
#   # change permission to allow us to run mknod later
#   echo 'b 7:* rwm' > /sys/fs/cgroup/devices/devices.allow
#   echo 'b 7:* rwm' > /sys/fs/cgroup/devices${devices_subdir}/devices.allow
#
#   # Setup loop devices
#   for i in {0..256}
#   do
#     rm -f /dev/loop$i
#     mknod -m777 /dev/loop$i b 7 $i
#   done
#
#   # Make XFS volume
#   truncate -s 8G /xfs_volume
#   mkfs.xfs -b size=4096 /xfs_volume
#
#   # Mount XFS
#   mkdir /mnt/garden-storage
#   mount -t xfs -o pquota,noatime,nobarrier /xfs_volume /mnt/garden-storage
#   chmod 777 -R /mnt/garden-storage
#
#   umount /sys/fs/cgroup/devices
# }

# build_grootfs () {
#   echo "Building grootfs..."
#   export GARDEN_RUNC_PATH=${PWD}/garden-runc-release
#   export GROOTFS_BINPATH=${GARDEN_RUNC_PATH}/bin
#   mkdir -p ${GROOTFS_BINPATH}
#
#   pushd ${GARDEN_RUNC_PATH}/src/grootfs
#     export PATH=${GROOTFS_BINPATH}:${PATH}
#
#     # Set up btrfs volume and loopback devices in environment
#     create_garden_storage
#     umount /sys/fs/cgroup
#
#     make
#
#     mv $PWD/build/grootfs $GROOTFS_BINPATH
#     echo "grootfs installed."
#
#     groupadd iamgroot -g 4294967294
#     useradd iamgroot -u 4294967294 -g 4294967294
#     echo "iamgroot:1:4294967293" > /etc/subuid
#     echo "iamgroot:1:4294967293" > /etc/subgid
#   popd
# }

# set_garden_rootfs () {
#   # use the 1.29 version of tar that's installed in the inigo-ci docker image
#   ln -sf /usr/local/bin/tar "${GARDEN_BINPATH}"
#
#   tar cpf /tmp/rootfs.tar -C /opt/inigo/rootfs .
#   export GARDEN_ROOTFS=/tmp/rootfs.tar
# }

function Setup-Gopath() {
	param([string] $dir)
  Write-Host "Starting Setup-Gopath"
  Push-Location $dir

  bosh sync-blobs

  #Have a way of copying envoy proxy

  $env:GOPATH_ROOT=($pwd).path

  $env:GOPATH="${env:GOPATH_ROOT}"
  $env:PATH="${env:GOPATH_ROOT}/bin:${env:PATH}"

  # install application dependencies
  echo "Installing gnatsd ..."
  go install github.com/apcera/gnatsd

  Pop-Location
  Write-Host "Finished Setup-Gopath"
}

function Install-Ginkgo() {
	param([string] $dir)
  Write-Host "Starting Install-Ginkgo"
  Push-Location $dir
  go install github.com/onsi/ginkgo/ginkgo
  Pop-Location
  Write-Host "Finished Install-Ginkgo"
}

# Remove-Item -Recurse -Force -ErrorAction Ignore $PWD/diego-release/src/code.cloudfoundry.org/guardian/vendor/github.com/onsi/ginkgo
# Remove-Item -Recurse -Force -ErrorAction Ignore $PWD/diego-release/src/code.cloudfoundry.org/guardian/vendor/github.com/onsi/gomega

# setup_dnsmasq

# Build-Gdn "$PWD/garden-runc-release"
#
# $env:ROUTER_GOPATH="$PWD/routing-release"
# $env:ROUTING_API_GOPATH=$env:ROUTER_GOPATH
#
# Setup-Gopath "$PWD/diego-release"
# Install-Ginkgo "$PWD/diego-release"

$env:APP_LIFECYCLE_GOPATH=${env:GOPATH_ROOT}
$env:AUCTIONEER_GOPATH=${env:GOPATH_ROOT}
$env:BBS_GOPATH=${env:GOPATH_ROOT}
$env:FILE_SERVER_GOPATH=${env:GOPATH_ROOT}
$env:HEALTHCHECK_GOPATH=${env:GOPATH_ROOT}
$env:LOCKET_GOPATH=${env:GOPATH_ROOT}
$env:REP_GOPATH=${env:GOPATH_ROOT}
$env:ROUTE_EMITTER_GOPATH=${env:GOPATH_ROOT}
$env:SSHD_GOPATH=${env:GOPATH_ROOT}
$env:SSH_PROXY_GOPATH=${env:GOPATH_ROOT}
$env:GARDEN_GOPATH=${env:GOPATH_ROOT}

# used for routing to apps; same logic that Garden uses.
# EXTERNAL_ADDRESS=$(ip route get 8.8.8.8 | sed 's/.*src\s\(.*\)\s/\1/;tx;d;:x')
# export EXTERNAL_ADDRESS

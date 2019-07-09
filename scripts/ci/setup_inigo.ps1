$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

$env:GOROOT="C:\var\vcap\packages\golang-1.12-windows\go"
$env:PATH= "$env:GOROOT\bin;$env:PATH"

function Build-GardenRunc(){
	param([string] $gardenRuncDir, [string] $wincReleaseDir)

  Write-Host "Building garden-runc"
  $env:GARDEN_RUNC_PATH = $gardenRuncDir
  $env:WINC_RELEASE_PATH = $wincReleaseDir

  push-location $env:GARDEN_RUNC_PATH
    $env:PATH = "$PWD\bin;$env:PATH"
    $env:GARDEN_BINPATH = "$PWD\bin"

    mkdir -Force "$env:GARDEN_RUNC_PATH\bin"

    $tarPath = (Get-Command tar).source
    cp -ErrorAction SilentlyContinue -Force $tarPath "$env:GARDEN_BINPATH"

    push-location ".\src\guardian"
      go build -mod vendor -o "$env:GARDEN_BINPATH\init.exe" ".\cmd\winit"
      if ($LastExitCode -ne 0) {
	throw "Building init.exe process returned error code: $LastExitCode"
      }
    pop-location
  pop-location


  push-location $env:WINC_RELEASE_PATH
    mkdir -Force "$env:WINC_RELEASE_PATH\bin"

    $env:GROOTFS_BINPATH = "$env:GARDEN_BINPATH"

    bosh sync-blobs
    if ($LastExitCode -ne 0) {
      throw "Syncing winc bosh blobs returned error code: $LastExitCode"
    }
    $mingwPath=(Get-ChildItem "blobs\mingw\x86_64-*.zip").FullName
    Expand-Archive -Force -Path "$mingwPath" -DestinationPath "$env:WINC_RELEASE_PATH\bin"
    $env:PATH = "$env:WINC_RELEASE_PATH\bin\mingw64\bin;$env:PATH"

    $env:GOPATH="$PWD"

    go build -o "$env:GARDEN_BINPATH\nstar.exe" "nstar"
    if ($LastExitCode -ne 0) {
      throw "Building nstar.exe process returned error code: $LastExitCode"
    }

    go build -o "$env:GROOTFS_BINPATH\grootfs.exe" "code.cloudfoundry.org/groot-windows"
    if ($LastExitCode -ne 0) {
      throw "Building grootfs.exe process returned error code: $LastExitCode"
    }

    gcc -c ".\src\code.cloudfoundry.org\groot-windows\volume\quota\quota.c" -o "$env:GROOTFS_BINPATH\quota.o"
    if ($LastExitCode -ne 0) {
      throw "Building quota.o process returned error code: $LastExitCode"
    }

    gcc -shared -o "$env:GROOTFS_BINPATH\quota.dll" "$env:GROOTFS_BINPATH\quota.o" -lole32 -loleaut32
    if ($LastExitCode -ne 0) {
      throw "Building quota.dll process returned error code: $LastExitCode"
    }

    go build -o "$env:GARDEN_BINPATH\winc.exe" "code.cloudfoundry.org/winc/cmd/winc"
    if ($LastExitCode -ne 0) {
      throw "Building winc.exe process returned error code: $LastExitCode"
    }

    go build -o "$env:GARDEN_BINPATH\winc-network.exe" -tags "hnsAcls" "code.cloudfoundry.org/winc/cmd/winc-network"
    if ($LastExitCode -ne 0) {
      throw "Building winc-network.exe process returned error code: $LastExitCode"
    }
  pop-location
}

function Set-GardenRootfs() {
  $env:GARDEN_ROOTFS="docker:///cloudfoundry/windows2016fs:2019"
  $env:GROOTFS_STORE_PATH="C:\grootfs-store"
  & "$env:GROOTFS_BINPATH\grootfs.exe" --driver-store "$env:GROOTFS_STORE_PATH" pull "$env:GARDEN_ROOTFS"
  if ($LastExitCode -ne 0) {
    throw "Pulling $env:GARDEN_ROOTFS returned error code: $LastExitCode"
  }
}

function Setup-ContainerNetworking() {
  Set-Content -Path "C:\winc-network.json" -Value '{
  "network_name": "winc-nat",
  "subnet_range": "172.30.0.0/22",
  "gateway_address": "172.30.0.1"
}'

  & "$env:GARDEN_BINPATH\winc-network.exe" --debug --log-format json --action delete --configFile "C:\winc-network.json"
  if ($LASTEXITCODE -ne 0) {
    throw "Deleting container network returned error code: $LastExitCode"
  }

  & "$env:GARDEN_BINPATH\winc-network.exe" --debug --log-format json --action create --configFile "C:\winc-network.json"
  if ($LASTEXITCODE -ne 0) {
    throw "Creating container network returned error code: $LastExitCode"
  }

  Set-NetFirewallProfile -All -DefaultInboundAction Block -DefaultOutboundAction Allow -Enabled True
}

function Setup-Gopath() {
	param([string] $dir)

  Push-Location $dir
    bosh sync-blobs
    if ($LastExitCode -ne 0) {
      throw "Syncing diego bosh blobs returned error code: $LastExitCode"
    }

    # Have a way of copying envoy proxy

    $env:GOPATH_ROOT="$PWD"

    $env:GOPATH="${env:GOPATH_ROOT}"
    $env:PATH="${env:GOPATH_ROOT}/bin:${env:PATH}"

    # install application dependencies
    echo "Installing gnatsd ..."
    go install github.com/apcera/gnatsd
    if ($LastExitCode -ne 0) {
      throw "Installing gnatsd returned error code: $LastExitCode"
    }
  Pop-Location
}

function Install-Ginkgo() {
	param([string] $dir)
  Push-Location $dir
    go install github.com/onsi/ginkgo/ginkgo
    if ($LastExitCode -ne 0) {
      throw "Installing ginkgo returned error code: $LastExitCode"
    }
    $env:PATH="$env:PATH;$PWD/bin"
  Pop-Location
}

function Setup-Database() {
  $origCaFile="$env:GOPATH_ROOT\src\code.cloudfoundry.org\inigo\fixtures\certs\sql-certs\server-ca.crt"
  $origCertFile="$env:GOPATH_ROOT\src\code.cloudfoundry.org\inigo\fixtures\certs\sql-certs\server.crt"
  $origKeyFile="$env:GOPATH_ROOT\src\code.cloudfoundry.org\inigo\fixtures\certs\sql-certs\server.key"

  $caFile="C:\\mysql-certs\\server-ca.crt"
  $certFile="C:\\mysql-certs\\server.crt"
  $keyFile="C:\\mysql-certs\\server.key"
  mkdir -Force "C:\mysql-certs"

  cp $origCaFile $caFile
  cp $origCertFile $certFile
  cp $origKeyFile $keyFile

  Set-Content -Path "C:\tools\mysql\current\my.ini" -Encoding Ascii -Value "[mysqld]
basedir=C:\\tools\\mysql\\current
datadir=C:\\ProgramData\\MySQL\\data
ssl-cert=$certFile
ssl-key=$keyFile
ssl-ca=$caFile"

Restart-Service Mysql
}

function Setup-Consul {
  $CONSUL_DIR = "C:/consul"
  if(!(Test-Path -Path $CONSUL_DIR )) {
      New-Item -ItemType directory -Path $CONSUL_DIR
      (New-Object System.Net.WebClient).DownloadFile('https://releases.hashicorp.com/consul/0.7.0/consul_0.7.0_windows_amd64.zip', "$CONSUL_DIR/consul.zip")
      [System.IO.Compression.ZipFile]::ExtractToDirectory("$CONSUL_DIR/consul.zip", "$CONSUL_DIR")
  }

  $env:PATH = "$env:PATH;$CONSUL_DIR"
}

Remove-Item -Recurse -Force -ErrorAction Ignore $PWD/diego-release/src/code.cloudfoundry.org/guardian/vendor/github.com/onsi/ginkgo
Remove-Item -Recurse -Force -ErrorAction Ignore $PWD/diego-release/src/code.cloudfoundry.org/guardian/vendor/github.com/onsi/gomega

Build-GardenRunc "$PWD\garden-runc-release" "$PWD\winc-release"

$env:ROUTER_GOPATH="$PWD\routing-release"
$env:ROUTING_API_GOPATH=$env:ROUTER_GOPATH

Setup-Gopath "$PWD/diego-release"
Install-Ginkgo "$PWD/diego-release"
Set-GardenRootfs
Setup-ContainerNetworking
Setup-Database
Setup-Consul

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
$env:EXTERNAL_ADDRESS="foo"

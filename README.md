# Robust ChargeCtrl-OS Updates

Def.: ChargeCtrl = 
- Revolution Pi Connect+ 
- or Revolution Pi Connect SE 
- or Revolution Pi Connect 4 (in the future)

with

- Raspbian 10 (buster)
- set of installed Debian packages (see `debs-to-install`) and their dependencies
- some pre-configuration (e.g. SSH enabled) 

Desired outcome: ChargeCtrl can be updated to a new custom image based on Raspbian 11 bullseye *on live devices*. 
The update should be robust to sudden outages in power or internet connection.
The solution should be installable on live devices via a remote SSH connection.

## Hardware

- Revolution Pis
    - 1 RevPi Connect with a CM3 (Connect+)
    - 1 RevPi Connect with a CM4S (Connect SE)
    - 1 RevPi Connect with a CM4 (Connect 4)
    - important: don't remove the jumper cable from pins 6 (0V) to 7 (WD), otherwise a watchdog will cyclically reboot the device (https://revolutionpi.com/tutorials/uebersicht-revpi-connect/watchdog-connect/)
    - power supply
- Compute Module 3+ Development Kit with 2 Compute Module 3+ 32 GB
- USB RS485 adapter for serial connection to PC
- MikroTik VPN Router + power supply
- Ethernet cables

## Build of an image based on Raspbian 10 (buster) and RevPi software from KUNBUS

```
# get build script
git clone git@github.com:m-hegele/imagebakery.git
cd imagebakery
git checkout min-imagebuild

# get debs-to-install
cp <OneDrive>/debs-to-install/*.deb ./debs-to-install/

# get base image
curl -O https://downloads.raspberrypi.org/raspios_oldstable_lite_armhf/images/raspios_oldstable_lite_armhf-2022-09-26/2022-09-22-raspios-buster-armhf-lite.img.xz
xz -d 2022-09-22-raspios-buster-armhf-lite.img.xz
cp  2022-09-22-raspios-buster-armhf-lite.img chargectrl-netlight.img

# build image
sudo ./customize_image.sh --minimize chargectrl-netlight.img

# if you need to copy the image somewhere, compress it
xz -T0 --fast -f -k -v chargectrl-netlight.img
```

## Flashing the Image

plug in micro USB cable before booting the Pi

then flash chargectrl-netlight.img

- using BalenaEtcher (on Windows, Linux didn't work reliably)
- install current version of `rpiboot`: https://www.raspberrypi.com/documentation/computers/compute-module.html#windows-installer
- `sudo dd if=./chargehere-netlight.img of=/dev/sdc bs=4MiB conv=noerror,sync && sync`
    - Some implementations of dd don't have the sync command, therefore it is good to ensure it

### Checking the Image 

see https://dev.azure.com/ChargeHereOps/CH%20OPS%20Board/_wiki/wikis/CH-OPS-Board.wiki/22/RevPi-Setup

- connect to the RevPi 
    - easiest with a micro HDMI cable and a keyboard
    - otherwise: connect via Ethernet on port A, run a DHCP server and monitor it for new devices, use `ssh pi@<the-ip>`
- log in to the `pi` user with the standard `raspberry` password
- follow the instructions to configure the RevPi
    - the serial is the first number on the bottom left next to the DataMatrix
    - the MAC is in the center
- next time you will have to log in with the password that is printed on the right side of the RevPi
- check installation of ChargeHere software:
    - `dpkg -l ch-chargectrl` should show `ii ... 0.5.16+netlight2`
    - `systemctl status ch-ocppintf.service`
    - `systemctl status ch-loadctrl.service`

## Mender

### Build

using `mender-convert`

```
MENDER_ARTIFACT_NAME=release-1 ./docker-mender-convert \
    --disk-image input/golden-image-1.img \
    --config configs/raspberrypi3_config \
    --overlay input/rootfs_overlay_demo/

```

- The "rootfs-overlay" is a method for providing new and modified files to appear in the output image without needing to modify the input image.
- Adding a file, such as /etc/mender/mender.conf, to your "rootfs-overlay" will allow you customize the files that are included in the output images.
- The directory /var/lib/mender is on persistent storage, files are not overwritten by Mender updates.

### Deployment

#### Adding a device to Mender

- Connecting to the device through ssh and log in the Mender platform
- Go to the Dashboard and click on connect a device/connect more devices
- Click on Getting started, choose the device type -- Raspberry Pi 4 in our case -- and click on Next
- Copy paste the token that appears into the terminal -- ssh connection
- This will automatically trigger the installation of the Mender client on the device
- After the client is installed, the device appears on the platform in pending state.
- Click on Accept to manage the device

#### Deploy update

- Create a release by uploading an artifact and uploading it to the platform
- Select the release and Create a deployment out of the release
- Select the date for the deployment and the group of devices to deploy to
- Deploy the release update
- Testing for robustness - disconnecting the power supply and the network

Issues faced:

- Sometimes after triggering a deployment, the status gets stuck in "queued to start". This can be solved by executing sudo mender check-update in the device.
- During the first setup boot of the RevPi, we notice that the Mender Server takes the wrong MAC address of the device. Therefore, we first configure the RevPi and reboot, to then provision using Mender.


# Robust ChargeCtrl-OS Updates

Def.: ChargeCtrl = Revolution Pi Connect+ or Revolution Pi Connect SE with

- Raspbian 10 (buster)
- set of installed Debian packages (see `debs-to-install`) and their dependencies
- some pre-configuration (see `customize_image.sh`, e.g. SSH enabled) 

Desired outcome: ChargeCtrl can be updated to a new custom image (e.g. based on Raspbian 11 bullseye) *in the field*. 
The update should be robust to sudden outages in power or connection.
The solution should be installable via a remote SSH connection.

## Hardware

- 1 RevPi Connect with a CM3 (Connect+)
- 1 RevPi Connect with a CM4S (Connect SE)
- important: don't remove the jumper cable from pins 6 (0V) to 7 (WD), otherwise a watchdog will cyclically reboot the device (https://revolutionpi.com/tutorials/uebersicht-revpi-connect/watchdog-connect/)

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

# flash chargectrl-netlight.img, e.g. using BalenaEtcher
```

### New: Bullseye

```
curl -O https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-05-03/2023-05-03-raspios-bullseye-armhf-lite.img.xz
xz -d 2023-05-03-raspios-bullseye-armhf-lite.img.xz
cp  2023-05-03-raspios-bullseye-armhf-lite.img chargectrl-netlight-bullseye.img
sudo ./customize_image.sh --minimize chargectrl-netlight.img
```

### Checking the Image 

- connect to the RevPi (easiest with a micro HDMI cable and a keyboard, otherwise run a DHCP server and monitor it for new devices)
- log in to the `pi` user with the standard `raspberry` password
- follow the instructions to configure the RevPi
    - the serial is the first number on the bottom left next to the DataMatrix
    - the MAC is in the center
- next time you will have to log in with the password that is printed on the right side of the RevPi
- check installation of ChargeHere software:
    - `dpkg -l ch-chargectrl` should should `ii ... 0.5.16+netlight2`
    - `systemctl status ch-ocppintf.service`
    - `systemctl status ch-loadctrl.service`


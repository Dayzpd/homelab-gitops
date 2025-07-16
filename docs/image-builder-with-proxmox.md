## Add dedicated user and token

We'll add a dedicated user `capmox` and assign it `PVEDatastoreAdmin`, `PVESDNUser`, `PVESysAdmin`, and `PVEVMAdmin` roles:

*Note: Some capmox docs *

```bash
pveum user add capmox@pve
pveum aclmod / -user capmox@pve -role PVEDatastoreAdmin
pveum aclmod / -user capmox@pve -role PVESDNUser
pveum aclmod / -user capmox@pve -role PVESysAdmin
pveum aclmod / -user capmox@pve -role PVEVMAdmin
pveum user token add capmox@pve capi -privsep 0
```

## Building Image for CAPI

Clone the Kubernetes sigs image-builder repo:

```bash
git clone https://github.com/kubernetes-sigs/image-builder.git
```

If you already have packer installed, you may need to downgrade to the release
prior to hashicorp switching to BSL license. It'll likely be v1.9.5, but you can
easily find out which version you need by viewing the [image-builder/images/capi/hack/ensure-packer.sh](https://github.com/kubernetes-sigs/image-builder/blob/896c21a8414810aa53751c7cc7be42b719c666c6/images/capi/hack/ensure-packer.sh#L23C1-L24C17) file.

```bash
sudo apt purge -y packer
```

The afforementioned `ensure-packer.sh` script from image-builder can actually download the
correct packer version for you. It will be executed when building the prereqs for your particular
virtualization platform. In this case, I am using proxmox so I will run the following from inside the cloned `image-builder` repo:

```bash
make deps-proxmox
```

The appropriate version of the packer binary should be located inside your local `image-builder` 
repo at the path `images/capi/.local/bin/packer`. You can either append the absolute path to your PATH
env variable or just move the packer binary to the `/usr/bin` directory.

You'll now need to have the following env variables exported:

```bash
export PROXMOX_URL="https://homex10.local.zachary.day:8006/api2/json/"
export PROXMOX_USERNAME="capmox@pve!capi"
export PROXMOX_TOKEN="<REPLACE-ME>"
export PROXMOX_NODE="pve1"
export PROXMOX_ISO_POOL="local"
export PROXMOX_BRIDGE="kubeprod"
export PROXMOX_STORAGE_POOL="pve-disks"
export PROXMOX_ISO_FILE="iso/ubuntu-24.04.2-live-server-amd64.iso"
export PROXMOX_VMID="900"
```

As for my packer and cloud-init configuration, I do make some slight modifications to the defaults found within the image-builder repo.

### Packer Vars: ubuntu-2404.json

The priamry modification I've made is to the `boot_command_prefix`. I kickoff my packer builds from WSL and it's a real pain in the neck to get an http server exposed on my LAN that the build VM can access. So I tweaked the boot command to rely on cloudinit data from a cdrom drive (see the `packer.json.tmpl` for more details).

```json
{
  "bios": "ovmf",
  "boot_command_prefix": "c<wait>linux /casper/vmlinuz --- autoinstall ds='nocloud'<enter><wait10s>initrd /casper/initrd <enter><wait10s>boot <enter><wait10s>",
  "build_name": "ubuntu-2404-efi",
  "distribution_version": "2404",
  "distro_name": "ubuntu",
  "iso_checksum": "d6dab0c3a657988501b4bd76f1297c053df710e06e0c3aece60dead24f270b4d",
  "iso_checksum_type": "sha256",
  "iso_file": "{{env `ISO_FILE`}}",
  "iso_url": "https://releases.ubuntu.com/noble/ubuntu-24.04.2-live-server-amd64.iso",
  "os_display_name": "Ubuntu 24.04",
  "unmount_iso": "true",
  "version": "24.04"
}
```

### Packer Build Definition Template (packer.json.tmpl)

As mentioned above, I provide cloudinit configuration via a cdrom drive so I specify fill in `additional_iso_files`. For this I started out using a similar configuration to what I had done previously with Legacy/BIOS boot and Ubuntu 24.04 last year. Now the issue that I ran into when doing this was that the build VM would properly boot from the Ubuntu iso, but the cloud-init cidata iso would not be mounted properly. To overcome this issue, I found that leaving the `boot_iso` type as `ide` and  setting the cidata iso type to `scsi` under `additional_iso_files` worked.

Additionally, I also set the type of the network adapter to virtio and I also tweaked the `vmid` variable to allow me to set that from an environment variable.

Lastly, the proxmox image-builder uses some deprecated variables:

```json
{
  ...
  "iso_checksum": "{{user `iso_checksum_type`}}:{{user `iso_checksum`}}",
  "iso_file": "{{user `iso_file`}}",
  "iso_storage_pool": "{{user `iso_storage_pool`}}",
  "iso_url": "{{user `iso_url`}}",
  ...
}
```

If you refer to the [proxmox-iso packer builder plugin docs](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/iso#isos), they now want you to specify those values under the `boot_iso` variable. I did this just to get rid of the warnings.

```json
{
  "builders": [
    {
      "boot_command": [
        "{{user `boot_command_prefix`}}",
        "{{user `boot_media_path`}}",
        "{{user `boot_command_suffix`}}"
      ],
      "boot_wait": "{{user `boot_wait`}}",
      "task_timeout": "10m",
      "bios": "{{user `bios`}}",
      "communicator": "ssh",
      "cores": "{{user `cores`}}",
      "cpu_type": "{{user `cpu_type`}}",
      "disks": [
        {
          "disk_size": "{{user `disk_size`}}",
          "format": "{{user `disk_format`}}",
          "storage_pool": "{{user `storage_pool`}}",
          "type": "scsi"
        }
      ],
      "efi_config": {
        "efi_storage_pool": "{{user `storage_pool`}}",
        "pre_enrolled_keys": true,
        "efi_type": "4m"
      },
      "scsi_controller": "{{user `scsi_controller`}}",
      "http_directory": "{{user `http_directory`}}",
      "additional_iso_files": {
        "cd_files": [
          "{{user `http_directory`}}/meta-data",
          "{{user `http_directory`}}/user-data"
        ],
        "cd_label": "cidata",
        "iso_storage_pool": "{{user `iso_storage_pool`}}",
        "unmount": "{{user `unmount_iso`}}",
        "type": "scsi"
      },
      "insecure_skip_tls_verify": true,
      "boot_iso": {
        "iso_url": "{{user `iso_url`}}",
        "iso_checksum": "{{user `iso_checksum_type`}}:{{user `iso_checksum`}}",
        "iso_storage_pool": "{{user `iso_storage_pool`}}",
        "unmount": "{{user `unmount_iso`}}",
        "type": "ide"
      },
      "memory": "{{user `memory`}}",
      "name": "{{user `build_name`}}",
      "network_adapters": [
        {
          "bridge": "{{user `bridge`}}",
          "mtu": "{{ user `mtu` }}",
          "vlan_tag": "{{user `vlan_tag`}}"
        }
      ],
      "node": "{{ user `node` }}",
      "numa": "{{ user `numa` }}",
      "sockets": "{{user `sockets`}}",
      "ssh_password": "{{user `ssh_password`}}",
      "ssh_timeout": "2h",
      "ssh_username": "{{user `ssh_username`}}",
      "template_name": "{{ user `artifact_name` }}",
      "type": "proxmox-iso",
      "vm_id": "{{user `vmid`}}"
    }
  ],
  "post-processors": [
    {
      "environment_vars": [
        "CUSTOM_POST_PROCESSOR={{user `custom_post_processor`}}"
      ],
      "inline": [
        "if [ \"$CUSTOM_POST_PROCESSOR\" != \"true\" ]; then exit 0; fi",
        "{{user `custom_post_processor_command`}}"
      ],
      "name": "custom-post-processor",
      "type": "shell-local"
    }
  ],
  "provisioners": [
    {
      "environment_vars": [
        "BUILD_NAME={{user `build_name`}}"
      ],
      "inline": [
        "if [ $BUILD_NAME != \"ubuntu\" ]; then exit 0; fi",
        "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
        "sudo apt-get -qq update",
        "echo done"
      ],
      "inline_shebang": "/bin/bash -e",
      "type": "shell"
    },
    {
      "environment_vars": [
        "PYPY_HTTP_SOURCE={{user `pypy_http_source`}}"
      ],
      "execute_command": "BUILD_NAME={{user `build_name`}}; if [[ \"${BUILD_NAME}\" == *\"flatcar\"* ]]; then sudo {{.Vars}} -S -E bash '{{.Path}}'; fi",
      "script": "./packer/files/flatcar/scripts/bootstrap-flatcar.sh",
      "type": "shell"
    },
    {
      "ansible_env_vars": [
        "ANSIBLE_SSH_ARGS='{{user `existing_ansible_ssh_args`}} {{user `ansible_common_ssh_args`}}'",
        "KUBEVIRT={{user `kubevirt`}}"
      ],
      "extra_arguments": [
        "--extra-vars",
        "{{user `ansible_common_vars`}}",
        "--extra-vars",
        "{{user `ansible_extra_vars`}}",
        "--extra-vars",
        "{{user `ansible_user_vars`}}",
        "--scp-extra-args",
        "{{user `ansible_scp_extra_args`}}"
      ],
      "playbook_file": "./ansible/firstboot.yml",
      "type": "ansible",
      "user": "builder"
    },
    {
      "expect_disconnect": true,
      "inline": [
        "sudo reboot now"
      ],
      "inline_shebang": "/bin/bash -e",
      "type": "shell"
    },
    {
      "ansible_env_vars": [
        "ANSIBLE_SSH_ARGS='{{user `existing_ansible_ssh_args`}} {{user `ansible_common_ssh_args`}}'",
        "KUBEVIRT={{user `kubevirt`}}"
      ],
      "extra_arguments": [
        "--extra-vars",
        "{{user `ansible_common_vars`}}",
        "--extra-vars",
        "{{user `ansible_extra_vars`}}",
        "--extra-vars",
        "{{user `ansible_user_vars`}}",
        "--scp-extra-args",
        "{{user `ansible_scp_extra_args`}}"
      ],
      "pause_before": "10s",
      "playbook_file": "./ansible/node.yml",
      "type": "ansible",
      "user": "builder"
    },
    {
      "arch": "{{user `goss_arch`}}",
      "format": "{{user `goss_format`}}",
      "format_options": "{{user `goss_format_options`}}",
      "goss_file": "{{user `goss_entry_file`}}",
      "inspect": "{{user `goss_inspect_mode`}}",
      "tests": [
        "{{user `goss_tests_dir`}}"
      ],
      "type": "goss",
      "url": "{{user `goss_url`}}",
      "use_sudo": true,
      "vars_file": "{{user `goss_vars_file`}}",
      "vars_inline": {
        "ARCH": "amd64",
        "OS": "{{user `distro_name` | lower}}",
        "OS_VERSION": "{{user `distribution_version` | lower}}",
        "PROVIDER": "qemu",
        "containerd_version": "{{user `containerd_version`}}",
        "kubernetes_cni_deb_version": "{{ user `kubernetes_cni_deb_version` }}",
        "kubernetes_cni_rpm_version": "{{ split (user `kubernetes_cni_rpm_version`) \"-\" 0 }}",
        "kubernetes_cni_source_type": "{{user `kubernetes_cni_source_type`}}",
        "kubernetes_cni_version": "{{user `kubernetes_cni_semver` | replace \"v\" \"\" 1}}",
        "kubernetes_deb_version": "{{ user `kubernetes_deb_version` }}",
        "kubernetes_rpm_version": "{{ split (user `kubernetes_rpm_version`) \"-\" 0  }}",
        "kubernetes_source_type": "{{user `kubernetes_source_type`}}",
        "kubernetes_version": "{{user `kubernetes_semver` | replace \"v\" \"\" 1}}"
      },
      "version": "{{user `goss_version`}}"
    },
    {
      "expect_disconnect": true,
      "inline": [
        "echo '{{user `ssh_password`}}' | sudo -S -E sh -c 'usermod -L {{user `ssh_username`}} && shutdown'"
      ],
      "inline_shebang": "/bin/bash -e",
      "type": "shell"
    }
  ],
  "variables": {
    "ansible_common_vars": "",
    "ansible_extra_vars": "ansible_python_interpreter=/usr/bin/python3",
    "ansible_scp_extra_args": "",
    "ansible_user_vars": "",
    "artifact_name": "{{user `build_name`}}-kube-{{user `kubernetes_semver`}}",
    "boot_wait": "10s",
    "bios": "seabios",
    "bridge": "{{env `PROXMOX_BRIDGE`}}",
    "build_timestamp": "{{timestamp}}",
    "containerd_sha256": null,
    "containerd_url": "https://github.com/containerd/containerd/releases/download/v{{user `containerd_version`}}/cri-containerd-cni-{{user `containerd_version`}}-linux-amd64.tar.gz",
    "containerd_version": null,
    "cores": "2",
    "crictl_url": "https://github.com/kubernetes-sigs/cri-tools/releases/download/v{{user `crictl_version`}}/crictl-v{{user `crictl_version`}}-linux-amd64.tar.gz",
    "crictl_version": null,
    "disk_format": "qcow2",
    "disk_size": "20G",
    "existing_ansible_ssh_args": "{{env `ANSIBLE_SSH_ARGS`}}",
    "http_directory": "./packer/proxmox/linux/{{user `distro_name`}}/http/{{user `version`}}.efi",
    "iso_storage_pool": "{{env `PROXMOX_ISO_POOL`}}",
    "kubernetes_cni_deb_version": null,
    "kubernetes_cni_http_source": null,
    "kubernetes_cni_rpm_version": null,
    "kubernetes_cni_semver": null,
    "kubernetes_cni_source_type": null,
    "kubernetes_container_registry": null,
    "kubernetes_deb_gpg_key": null,
    "kubernetes_deb_repo": null,
    "kubernetes_deb_version": null,
    "kubernetes_http_source": null,
    "kubernetes_load_additional_imgs": null,
    "kubernetes_rpm_gpg_check": null,
    "kubernetes_rpm_gpg_key": null,
    "kubernetes_rpm_repo": null,
    "kubernetes_rpm_version": null,
    "kubernetes_semver": null,
    "kubernetes_series": null,
    "kubernetes_source_type": null,
    "memory": "2048",
    "mtu": "{{env `PROXMOX_MTU`}}",
    "node": "{{env `PROXMOX_NODE`}}",
    "numa": "false",
    "oem_id": "{{ user `oem_id` }}",
    "proxmox_url": "{{env `PROXMOX_URL`}}",
    "sockets": "2",
    "ssh_password": "$SSH_PASSWORD",
    "ssh_username": "builder",
    "storage_pool": "{{env `PROXMOX_STORAGE_POOL`}}",
    "token": "{{env `PROXMOX_TOKEN`}}",
    "username": "{{env `PROXMOX_USERNAME`}}",
    "vlan_tag": "{{env `PROXMOX_VLAN`}}",
    "vmid": "{{env `PROXMOX_VMID`}}",
    "scsi_controller": "virtio-scsi-pci"
  }
}

```

Now we can build the image:

```bash
make build-proxmox-ubuntu-2404
```

### Errors Encountered with Proxmox Image-Builder

Just a tip. When the subiquity installer fails, it'll dump the crash logs into the `/var/crash` directory. You can get shell access afterwards, but I personally find inspecting the logs from a shell to be annoying. Much easier to do so within an IDE like VSCode. So I'd recommend having some way to export those logs like uploading to an FTP server. The installer environment does have the `inetutils-ftp` client available so I just uploaded the crash logs to an FTP server I have running on Truenas Scale. If you want to get fancy with it, you could probably add some [error commands](https://canonical-subiquity.readthedocs-hosted.com/en/latest/reference/autoinstall-reference.html#error-commands) to your `user-data` file.

Since this is just for my homelab, I export those crash logs manually.

```bash
ftp truenas.local.zachary.day
```

Then after logging in, I upload the crash log:

```bash
ftp> put /var/crash/<REPLACE-WITH-CRASH-LOG-FILE-NAME>.crash /crash.log
```

#### Name Resolution

**TLDR: Double check your firewall rules to ensure your VMs have access to install packages.**

One error that I encountered initially was that my build failed when trying to install `qemu-guest-agent`. I suspected that the issue may have been related to network connectivity so I added a ping to my early commands:

```yaml
  early-commands:
    - systemctl stop ssh
    - ping -c 4 google.com || echo "Network not reachable"
```

Afterwards, I saw the following in the subiquity installer crash logs:

```
Jan 09 11:37:16 ubuntu-server subiquity_echo.1571[1922]: ping: google.com: Temporary failure in name resolution
Jan 09 11:37:16 ubuntu-server subiquity_echo.1571[1920]: Network not reachable
Jan 09 11:37:16 ubuntu-server subiquity_event.1571[1571]:  subiquity/Early/run/command_1: ping -c 4 google.com || echo "Network not reachable"
```

I also noticed other name resolution errors throughout the installer crash logs as well. As you may have noticed in the exported environment variables, I do provide a VLAN ID. I hadn't looked at the VLAN configuration inside PfSense in a while and realized that I had never actually set any firewall rules. PfSense denys all traffic by default so I just needed to add a default rule to allow all which resolved the issue.

#### Corrupted ISO Media

**TLDR: Either have packer download the ISO and validate checksum or manually pre-download ISO and verify checksum yourself.**

Oftentimes, I would run into issues during the subiquity autoinstall. Most notably, I'd see errors like the following. Should you see anything like that, there's a good chance that your ISO is corrupted. In particular, if you download the Ubuntu Server ISO ahead of time and define a `iso_file` as opposed to an `iso_url` for the packer build, then the chances are even higher that the ISO is corrupted. Should you want to continue using a pre-downloaded ISO instead of having packer download it from a URL, make sure to validate the sha256 checksum before running your packer build.

```
Jan 09 13:17:14 ubuntu-server kernel: SQUASHFS error: xz decompression failed, data probably corrupt
Jan 09 13:17:14 ubuntu-server kernel: SQUASHFS error: Failed to read block 0x6928624: -5
Jan 09 13:17:14 ubuntu-server kernel: SQUASHFS error: xz decompression failed, data probably corrupt
Jan 09 13:17:14 ubuntu-server kernel: SQUASHFS error: Failed to read block 0x6928624: -5
Jan 09 13:17:14 ubuntu-server subiquity_log.1584[2810]: rsync: [sender] read errors mapping "/tmp/tmpfm5_7ujy/mount/usr/lib/x86_64-linux-gnu/libperl.so.5.38.2": Input/output error (5)
Jan 09 13:17:16 ubuntu-server kernel: SQUASHFS error: xz decompression failed, data probably corrupt
Jan 09 13:17:16 ubuntu-server kernel: SQUASHFS error: Failed to read block 0x6928624: -5
Jan 09 13:17:16 ubuntu-server subiquity_log.1584[2810]: rsync: [sender] read errors mapping "/tmp/tmpfm5_7ujy/mount/usr/lib/x86_64-linux-gnu/libperl.so.5.38.2": Input/output error (5)
Jan 09 13:17:16 ubuntu-server subiquity_log.1584[2810]: ERROR: usr/lib/x86_64-linux-gnu/libperl.so.5.38.2 failed verification -- update discarded.
Jan 09 13:17:23 ubuntu-server kernel: SQUASHFS error: xz decompression failed, data probably corrupt
Jan 09 13:17:23 ubuntu-server kernel: SQUASHFS error: Failed to read block 0x3ceb52b: -5
Jan 09 13:17:23 ubuntu-server kernel: SQUASHFS error: Unable to read fragment cache entry [3ceb52b]
Jan 09 13:17:23 ubuntu-server kernel: SQUASHFS error: Unable to read fragment cache entry [3ceb52b]
Jan 09 13:17:23 ubuntu-server kernel: SQUASHFS error: Unable to read page, block 3ceb52b, size 8ba0
Jan 09 13:17:23 ubuntu-server kernel: SQUASHFS error: Unable to read fragment cache entry [3ceb52b]
Jan 09 13:17:23 ubuntu-server kernel: SQUASHFS error: Unable to read fragment cache entry [3ceb52b]
Jan 09 13:17:23 ubuntu-server kernel: SQUASHFS error: Unable to read page, block 3ceb52b, size 8ba0
Jan 09 13:17:23 ubuntu-server kernel: SQUASHFS error: Unable to read fragment cache entry [3ceb52b]
Jan 09 13:17:23 ubuntu-server kernel: SQUASHFS error: Unable to read fragment cache entry [3ceb52b]
Jan 09 13:17:23 ubuntu-server kernel: SQUASHFS error: Unable to read page, block 3ceb52b, size 8ba0
```

```
Jan 09 13:17:24 ubuntu-server subiquity_log.1584[2810]: ERROR: usr/share/locale/sq/LC_MESSAGES/iso_3166-2.mo failed verification -- update discarded.
Jan 09 13:17:24 ubuntu-server subiquity_log.1584[2810]: ERROR: usr/share/locale/sq/LC_MESSAGES/iso_3166-3.mo failed verification -- update discarded.
Jan 09 13:17:24 ubuntu-server subiquity_log.1584[2810]: ERROR: usr/share/locale/sq/LC_MESSAGES/iso_4217.mo failed verification -- update discarded.
Jan 09 13:17:24 ubuntu-server subiquity_log.1584[2810]: ERROR: usr/share/locale/sq/LC_MESSAGES/iso_639-2.mo failed verification -- update discarded.
Jan 09 13:17:24 ubuntu-server subiquity_log.1584[2810]: ERROR: usr/share/locale/sq/LC_MESSAGES/iso_639-3.mo failed verification -- update discarded.
Jan 09 13:17:24 ubuntu-server subiquity_log.1584[2810]: ERROR: usr/share/locale/sq/LC_MESSAGES/iso_639-5.mo failed verification -- update discarded.
Jan 09 13:17:24 ubuntu-server subiquity_log.1584[2810]: ERROR: usr/share/locale/sq/LC_MESSAGES/python-apt.mo failed verification -- update discarded.
Jan 09 13:17:24 ubuntu-server subiquity_log.1584[2810]: ERROR: usr/share/locale/sq/LC_MESSAGES/update-notifier.mo failed verification -- update discarded.
Jan 09 13:17:27 ubuntu-server systemd[1]: systemd-timedated.service: Deactivated successfully.
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: rsync error: some files/attrs were not transferred (see previous errors) (code 23) at main.c(1338) [sender=3.2.7]
Jan 09 13:17:32 ubuntu-server curtin_event.1584.7[2814]: finish: cmd-install/stage-extract/builtin/cmd-extract: FAIL: acquiring and extracting image from cp:///tmp/tmpfm5_7ujy/mount
Jan 09 13:17:32 ubuntu-server curtin_event.1584.7[2814]: finish: cmd-install/stage-extract/builtin/cmd-extract: FAIL: curtin command extract
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: finish: cmd-install/stage-extract/builtin/cmd-extract: FAIL: acquiring and extracting image from cp:///tmp/tmpfm5_7ujy/mount
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: finish: cmd-install/stage-extract/builtin/cmd-extract: FAIL: curtin command extract
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: Traceback (most recent call last):
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]:   File "/snap/subiquity/6066/lib/python3.10/site-packages/curtin/commands/main.py", line 202, in main
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]:     ret = args.func(args)
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]:   File "/snap/subiquity/6066/lib/python3.10/site-packages/curtin/commands/extract.py", line 267, in extract
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]:     extract_source(source, target, extra_rsync_args=extra_rsync_args)
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]:   File "/snap/subiquity/6066/lib/python3.10/site-packages/curtin/commands/extract.py", line 209, in extract_source
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]:     copy_to_target(root_dir, target, extra_rsync_args=extra_rsync_args)
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]:   File "/snap/subiquity/6066/lib/python3.10/site-packages/curtin/commands/extract.py", line 225, in copy_to_target
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]:     util.subp(
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]:   File "/snap/subiquity/6066/lib/python3.10/site-packages/curtin/util.py", line 323, in subp
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]:     return _subp(*args, **kwargs)
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]:   File "/snap/subiquity/6066/lib/python3.10/site-packages/curtin/util.py", line 172, in _subp
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]:     raise ProcessExecutionError(stdout=out, stderr=err,
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: curtin.util.ProcessExecutionError: Unexpected error while running command.
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: Command: ['rsync', '-aXHAS', '--one-file-system', '/tmp/tmpfm5_7ujy/mount/', '.']
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: Exit code: 23
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: Reason: -
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: Stdout: ''
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: Stderr: ''
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: Unexpected error while running command.
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: Command: ['rsync', '-aXHAS', '--one-file-system', '/tmp/tmpfm5_7ujy/mount/', '.']
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: Exit code: 23
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: Reason: -
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: Stdout: ''
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: Stderr: ''
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: builtin command failed
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: finish: cmd-install/stage-extract/builtin: FAIL: running 'curtin extract'
Jan 09 13:17:32 ubuntu-server curtin_event.1584.7[2810]: finish: cmd-install/stage-extract/builtin: FAIL: running 'curtin extract'
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: builtin took 38.855 seconds
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: stage_extract took 38.855 seconds
Jan 09 13:17:32 ubuntu-server subiquity_log.1584[2810]: finish: cmd-install/stage-extract: FAIL: writing install sources to disk
Jan 09 13:17:32 ubuntu-server curtin_event.1584.7[2810]: finish: cmd-install/stage-extract: FAIL: writing install sources to disk
```

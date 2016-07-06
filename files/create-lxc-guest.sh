#!/bin/bash

set -e

wait_for_ssh()
{
	declare hostname="${1}"
	while ! nmap -p 22 "${hostname}" 2>"/dev/null" | grep "^22" | grep "open" >"/dev/null"; do
  		echo >"/dev/null"
			sleep 1
	done
}

create_lxc()
{
	declare hostname="${1}"
	declare lxc_dp="/var/lib/lxc"
	declare rootfs_dp="${lxc_dp}/${hostname}/rootfs"

  # -t download -- -d centos -r 7 -a amd64
	lxc-create -n "${hostname}" -t "centos" -- -R 7 --fqdn "${hostname}"

	cat <<-EOF >"${rootfs_dp}/etc/sysconfig/network-scripts/ifcfg-eth0"
	DEVICE=eth0
	BOOTPROTO=dhcp
	ONBOOT=yes
	TYPE=Ethernet
	HOSTNAME=${hostname}
	EOF

 	sed -i -r -e 's/^#?GSSAPIAuthentication .+/GSSAPIAuthentication no/' "${rootfs_dp}/etc/ssh/sshd_config"
	sed -i -r -e 's/^#?UseDNS .+/UseDNS no/' "${rootfs_dp}/etc/ssh/sshd_config"
	sed -i -r 	-e 's/^enabled=.*/enabled=0/' "${rootfs_dp}/etc/yum/pluginconf.d/fastestmirror.conf"

	mkdir -p "${rootfs_dp}/root/.ssh"
	su - "${SUDO_USER}" -c "cat '/home/${SUDO_USER}/.ssh/id_rsa.pub'" >"${rootfs_dp}/root/.ssh/authorized_keys"
	echo root:root | chroot "${rootfs_dp}" chpasswd

	#chroot "${rootfs_dp}" /bin/sh -c 'yum -y install "epel-release" && yum -y install "avahi" "nss-mdns" && systemctl enable "avahi-daemon.service"'
	#sed -i -r -e 's,^#?rlimit-nproc=(.*),#rlimit-nproc=\1,g' "${rootfs_dp}/etc/avahi/avahi-daemon.conf"

	#sed -i "s,\(ExecStart=.*\),\1 --no-rlimits,g" "${rootfs_dp}/usr/lib/systemd/system/avahi-daemon.service"
	#sed -i -e 's/^#domain-name=.*/domain-name=lxc/' "${rootfs_dp}/etc/avahi/avahi-daemon.conf"

	#su - "${SUDO_USER}" -c "ssh-keygen -R '${hostname}.lxc'"
}

main()
{
  declare fqdn="${1}"
  declare hostname="$( echo "${fqdn}" | cut -d'.' -f1 )"

	declare return_code=1

	if ! lxc-ls -1 | grep -q "${hostname}"; then
		create_lxc "${hostname}"
		return_code=0
	fi

	if ! lxc-ls -1 --running | grep -q "${hostname}"; then
		lxc-start -n "${hostname}"
		wait_for_ssh "${fqdn}"
		return_code=0
	fi

	return ${return_code}
	#su - "${SUDO_USER}" -c "ssh-keyscan '${hostname}.lxc' >>'/home/${SUDO_USER}/.ssh/known_hosts'"
}

main "${@}"

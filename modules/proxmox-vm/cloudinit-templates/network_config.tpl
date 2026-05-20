#cloud-config
version: 2
ethernets:
  alleths:
    match:
      name: "en*"
%{ if enable_dhcp }
    dhcp4: true
%{ else }
    dhcp4: no
    addresses: [${ip_address}]
    gateway4: ${gateway}
    nameservers:
      addresses:
      %{ for dns in dns_servers ~}
        - ${dns}
      %{ endfor ~}
%{ endif }
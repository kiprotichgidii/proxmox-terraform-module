version: 1
config:
%{ if enable_dhcp ~}
  - type: physical
    name: ${nic}
    subnets:
      - type: dhcp
%{ else ~}
  - type: physical
    name: ${nic}
    subnets:
      - type: static
        address: ${ip_address}
        gateway: ${gateway}
        dns_nameservers:
%{ for dns in dns_servers ~}
          - ${dns}
%{ endfor ~}
%{ endif ~}
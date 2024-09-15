# nftables Port Knocking How-To

Port knocking is a technique to conceal a listening port and disallow connections to it, while keeping the possibility to open it for a remote address not known in advance. To open such port for a specific IP, packets are sent from that IP in the right order to the sequence of predefined ports.

While user space tools exist to implement port knocking (see [`knockd(1)`](https://linux.die.net/man/1/knockd)), it is possible to do it completely in nftables.

To detect port sequences in nftables we can use dynamic IP sets, populated when the ports are hit.


## Initial firewall configuration

For the sake of simplicity, let's assume we have a machine with only outbound connections allowed and all inbound connections filtered ("stealth" mode):

```nftables
table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;

        iif lo accept
        ct state established,related accept

        counter drop
    }
}
```

The same approach can be applied to a firewall rejecting packets instead of dropping them, of course.

## Port knocking implementation

We are going to use UDP packets for knocking, which are easier to send than TCP SYN packets without special tools and root privileges.

To track already knocked ports we create three IPv4 sets for source addresses and populate them when the ports are knocked in the right order. Once the address is added to the last set, we allow the connection (in this example — to SSH port).

Here is how we create the first set:

```nftables
set portknock_stage1 {
    type ipv4_addr;
    flags timeout;
    size 65536;
}
```

We put all port knocking rules into a separate chain to interrupt the processing with `return`.  Here is the rule to add the IP to the set if the first port is knocked:

```nftables
udp dport 7000 counter add @portknock_stage1 { ip saddr timeout 1s }
```

We proceed with checking the second port in the sequence only if the address is already present in the first set:

```nftables
ip saddr != @portknock_stage1 counter return
udp dport 8000 counter add @portknock_stage2 { ip saddr timeout 1s }"
```

And so on, finally adding the address to the final set allowing SSH connection.

Addresses are automatically removed from the sets after a timeout of one second for the repeated scanning of the entire port range to not easily trigger the rules.

See [`nftables.conf`](./nftables.conf) for the complete example. It allows connecting only from IPv4 addresses, but can be trivially extended with IPv6 sets/rules. Of course, you should use your own sequence of ports in a real application.


## Sending UDP packets

We can send a single UDP packet from bash using its special device `/dev/udp/$HOST/$PORT`:

```bash
echo -n hello > /dev/udp/1.1.1.1/7000
```

Sending the complete knocking sequence is implemented in [`knock.sh`](./knock.sh). Sleeps are needed to reduce the chances of packet reordring in transit.


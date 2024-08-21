{ config, pkgs, lib, ... }:

let
  assignEIP = pkgs.writeShellApplication {
    name = "assign-eip";
    runtimeInputs = [ pkgs.awscli2 pkgs.curl ];
    text = ''
      ELASTIC_IP="52.33.24.220"
      INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
      ALLOCATION_ID=$(aws ec2 describe-addresses --public-ips $ELASTIC_IP --query 'Addresses[0].AllocationId' --output text)
      ASSOCIATION_ID=$(aws ec2 describe-addresses --public-ips $ELASTIC_IP --query 'Addresses[0].AssociationId' --output text)

      # Check if the Elastic IP is already associated
      if [ "$ASSOCIATION_ID" != "None" ]; then
        echo "Elastic IP is already associated with another instance. Disassociating..."
        aws ec2 disassociate-address --association-id "$ASSOCIATION_ID"
      fi

      # Assign the Elastic IP to the current instance
      aws ec2 associate-address --instance-id "$INSTANCE_ID" --allocation-id "$ALLOCATION_ID"
    '';

  };
in

{
  system.stateVersion = "23.05";
  security.acme = {
    acceptTerms = true;
    defaults.email = "rwendt1337@gmail.com";
    certs = {
      "flakery.dev" = {
        domain = "www.flakery.dev";
        dnsProvider = "route53"; # Specify Route53 as the DNS provider
        # Provide the AWS credentials for Route53
        awsAccessKeyId = (lib.removeSuffix "\n" (builtins.readFile /aws-access-key-id));
        awsSecretAccessKey = (lib.removeSuffix "\n" (builtins.readFile /aws-secret-access-key));
      };
    };
  };

  services.caddy = {
    enable = true;
    # 301 redirect flakery.dev to www.flakery.dev
    virtualHosts."flakery.dev".extraConfig = ''
      redir https://www.flakery.dev{uri}
    '';

  };

  # caddy depends on assign-eip
  systemd.services.caddy.after = [ "assign-eip" ];
  systemd.services.caddy.requires = [ "assign-eip" ];

  systemd.services.assign-eip = {
    description = "Assign Elastic IP to instance";
    path = with pkgs; [ awscli2 curl ];
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
    serviceConfig.ExecStart = "${assignEIP}/bin/assign-eip";
    serviceConfig.RestartSec = 32; # Delay between retries
    # serviceConfig.StartLimitBurst = 16; # Number of retry attempts
    serviceConfig.StartLimitIntervalSec = 256; # Time window for retry attempts
    serviceConfig.Restart = "on-failure";
    # add aws access key and secret key to the environment
    environment = {
      AWS_ACCESS_KEY_ID = (pkgs.lib.removeSuffix "\n" (builtins.readFile /aws-access-key-id));
      AWS_SECRET_ACCESS_KEY = (pkgs.lib.removeSuffix "\n" (builtins.readFile /aws-secret-access-key));
    };

  };

  users.users.flakery = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  };
  # allow sudo without password for wheel
  security.sudo.wheelNeedsPassword = false;

  # port 22
  networking.firewall.allowedTCPPorts = [ 22 ];

  services.openssh = {
    enable = true;
    # require public key authentication for better security
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  users.users."flakery".openssh.authorizedKeys.keys = [
    # replace with your ssh key 
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCs/e5M8zDNH5DUmqCGKM0OhHKU5iHFum3IUekq8Fqvegur7G2fhsmQnp09Mjc5pEw2AbfTYz11WMHsvC5WQdRWSS2YyZHYsPb9zIsVBNcss+H5x63ItsDjmbrS6m/9r7mRBOiN265+Mszc5lchFtRFetpi9f+EBis9r8atyPlsz86IoS2UxSSWonBARU4uwy2+TT7+mYg3cQf7kp1Y1sTqshXmcHUC5UVSRk3Ny9IbIMhk19fOxr3y8gaXoT5lB0NSLO8XFNbNT6rjZXH1kpiPJh3xLlWBPQtbcLrpm8oSS51zH7+zAGb7mauDHu2RcfBgq6m1clZ6vff65oVuHOI7"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCqWQCbzrNA2JSWktRiN/ZCBihwgE7D9HJSvHqjdw/TOL8WrHVkkBCp8nm3z5THeXDAfpr5tYDE2KU0f6LSr88bmbn7DjAORgdTKdyJpzHGQeaS3YWnTi+Bmtv4mvCWk5HCCei0pciTh5KS8FFU8bGruFEUZAmDyk1EllFC+Gx8puPrAL3tl5JX6YXzTFFZirigJIlSP22WzN/1xmj1ahGo9J0E88mDMikPBs5+dhPOtIvNdd/qvi/wt7Jnmz/mZITMzPaKrei3gRQyvXfZChJpgGCj0f7wIzqv0Hq65kMILayHVT0F2iaVv+bBSvFq41n3DU4f5mn+IVIIPyDFaG/X"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJLb6cphbbtWQEVDpotwTY9IAam6WFpt8Dluap4wFiww root@ip-10-0-2-147.us-west-2.compute.internal"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGENQMz7ldqG4Zk/wfcwz1Uhl67eP5TLx1ZEmOUbqkME rw@rws-MacBook-Air.local"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9tjvxDXYRrYX6oDlWI0/vbuib9JOwAooA+gbyGG/+Q robertwendt@Roberts-Laptop.local"
  ];

}

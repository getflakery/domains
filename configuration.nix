{ config, pkgs, lib,  ... }:

let
  assignEIP = pkgs.writeShellApplication {
    name = "assign-eip";
    runtimeInputs = [ pkgs.awscli2 pkgs.curl ];
    text = ''
      ELASTIC_IP="54.186.174.84"
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

}

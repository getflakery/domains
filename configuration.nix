{ config, pkgs, lib,  ... }:

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

  # caddy server to redirect flakery.dev to www.flakery.dev
  services.caddy = {
    enable = true;
    config = ''
      flakery.dev {
        redir https://www.flakery.dev
      }
    '';
  };

}

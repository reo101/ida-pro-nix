# Non-module dependencies (`importApply`)
{ writeShellScript }:

# Service module
{
  config,
  options,
  lib,
  ...
}:
let
  inherit (lib)
    types
    ;

  cfg = config.vault-server;
  defaultDataDir = "/var/lib/hexvault";
in
{
  _class = "service";

  options.vault-server = {
    enable = lib.mkOption {
      type = types.bool;
      default = (lib.tryEval cfg.package.src or cfg.package).success;
      description = "Whether to run HexVault.";
    };

    package = lib.mkOption {
      type = types.package;
      description = "Package to use for HexVault.";
    };

    dataDir = lib.mkOption {
      type = types.path;
      description = ''
        State directory where HexVault stores its data.

        When left at the default, the systemd unit manages it through
        `StateDirectory`.
      '';
      default = defaultDataDir;
      example = "/srv/hexvault";
    };

    user = lib.mkOption {
      type = types.nullOr types.str;
      description = ''
        User the service runs as.

        When left as `null`, the unit uses `DynamicUser`.
      '';
      default = null;
      example = "hexvault";
    };

    group = lib.mkOption {
      type = types.nullOr types.str;
      description = ''
        Group the service runs as.

        When left as `null`, the unit uses `DynamicUser`.
      '';
      default = null;
      example = "hexvault";
    };

    port = lib.mkOption {
      type = types.nullOr types.port;
      description = "TCP port HexVault listens on.";
      default = 65433;
    };

    address = lib.mkOption {
      type = types.nullOr types.str;
      description = "IP address HexVault listens on.";
      default = "127.0.0.1";
    };

    certchain = lib.mkOption {
      type = types.str;
      description = "Path to the HexVault TLS certificate chain file.";
    };

    privkey = lib.mkOption {
      type = types.str;
      description = "Path to the HexVault TLS private key file.";
    };

    connectionString = lib.mkOption {
      type = types.str;
      description = "Connection string (for the SQLite database) for HexVault.";
      default = "${cfg.dataDir}/hexvault.db";
    };

    license = lib.mkOption {
      type = types.str;
      description = "Path to the HexVault license file.";
    };

    # TODO: generate from `settings` + `extraConfig`
    configFile = lib.mkOption {
      type = types.nullOr types.path;
      description = "Path to the HexVault license file.";
      default = null;
    };

    badreqDir = lib.mkOption {
      type = types.path;
      description = ''
        Directory where HexVault holds dumps of requests causing internal errors.

        When left at the default, the systemd unit manages it through
        `StateDirectory`.
      '';
      default = "${cfg.dataDir}/badreq";
      example = "/srv/hexvault/badreq";
    };

    vaultDir = lib.mkOption {
      type = types.path;
      description = ''
        Directory where HexVault holds vault files.

        When left at the default, the systemd unit manages it through
        `StateDirectory`.
      '';
      default = "${cfg.dataDir}/vault";
      example = "/srv/hexvault/vault";
    };

    extraArgs = lib.mkOption {
      type = types.listOf types.str;
      description = "Extra command-line arguments passed to HexVault.";
      default = [ ];
      example = [ "--verbose" ];
    };

    environment = lib.mkOption {
      type = types.attrsOf types.str;
      description = "Extra environment variables for the service.";
      default = { };
    };
  };

  config = {
    assertions = [
      {
        assertion = (cfg.user == null) == (cfg.group == null);
        message = "vault-server: set both `hexvault.user` and `hexvault.group`, or neither to use DynamicUser.";
      }
    ];

    process.argv = [
      (lib.getExe cfg.package)
    ]
    ++ lib.optionals (cfg.port != null) [
      "--port-number"
      (builtins.toString cfg.port)
    ]
    ++ lib.optionals (cfg.address != null) [
      "--ip-address"
      cfg.address
    ]
    ++ [
      "--certchain-file"
      cfg.certchain
    ]
    ++ [
      "--privkey-file"
      cfg.privkey
    ]
    ++ lib.optionals (cfg.connectionString != null) [
      "--connection-string"
      cfg.connectionString
    ]
    ++ [
      "--license-file"
      cfg.license
    ]
    ++ lib.optionals (cfg.configFile != null) [
      "--config-file"
      cfg.configFile
    ]
    ++ [
      "--badreq-dir"
      cfg.badreqDir
    ]
    ++ [
      "--vault-dir"
      cfg.vaultDir
    ]
    ++ cfg.extraArgs;
  }
  // lib.optionalAttrs (options ? systemd) {
    systemd.service = {
      enable = cfg.enable;
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = cfg.environment;

      serviceConfig = {
        Type = "simple";
        WorkingDirectory = cfg.dataDir;
        ExecStartPre = [
          (writeShellScript "setup-hexvault-db" ''
            '${lib.getExe cfg.package}' \
              --connection-string ${lib.escapeShellArg cfg.connectionString} \
              --license-file ${cfg.license} \
              --vault-dir ${lib.escapeShellArg cfg.vaultDir} \
              --recreate-schema
          '')
        ];
        Restart = "on-failure";
        RestartSec = 5;

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        PrivateDevices = true;
        ProtectSystem = "strict";
        ReadWritePaths = lib.unique [
          cfg.dataDir
          cfg.connectionString
          cfg.badreqDir
          cfg.vaultDir
        ];
      }
      // lib.optionalAttrs (cfg.user == null) {
        DynamicUser = true;
      }
      // lib.optionalAttrs (cfg.user != null) {
        User = cfg.user;
        Group = cfg.group;
      }
      // lib.optionalAttrs (cfg.dataDir == defaultDataDir) {
        StateDirectory = "hexvault";
      };
    };
  };
}

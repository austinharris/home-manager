{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.programs.beets;

  yamlFormat = pkgs.formats.yaml { };

in {
  meta.maintainers = with maintainers; [ rycee Scrumplex ];

  options = {
    programs.beets = {
      enable = mkOption {
        type = types.bool;
        default = if versionAtLeast config.home.stateVersion "19.03" then
          false
        else
          cfg.settings != { };
        defaultText = "false";
        description = ''
          Whether to enable the beets music library manager. This
          defaults to <literal>false</literal> for state
          version ≥ 19.03. For earlier versions beets is enabled if
          <option>programs.beets.settings</option> is non-empty.
        '';
      };

      package = mkOption {
        type = types.package;
        default = pkgs.beets;
        defaultText = literalExpression "pkgs.beets";
        example =
          literalExpression "(pkgs.beets.override { enableCheck = true; })";
        description = ''
          The <literal>beets</literal> package to use.
          Can be used to specify extensions.
        '';
      };

      settings = mkOption {
        type = yamlFormat.type;
        default = { };
        description = ''
          Configuration written to
          <filename>$XDG_CONFIG_HOME/beets/config.yaml</filename>
        '';
      };

      mpdIntegration = {
        enableStats = mkEnableOption "mpdstats plugin and service";
        enableUpdate = mkEnableOption "mpdupdate plugin";
        host = mkOption {
          type = types.str;
          default = "localhost";
          description = "Host mpdstats will connect to";
          example = "10.0.0.42";
        };
        port = mkOption {
          type = types.port;
          default = config.services.mpd.network.port;
          defaultText = literalExpression "config.services.mpd.network.port";
          description = "Port mpdstats will connect to";
          example = 6601;
        };
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      home.packages = [ cfg.package ];

      xdg.configFile."beets/config.yaml".source =
        yamlFormat.generate "beets-config" cfg.settings;
    })
    (mkIf (cfg.mpdIntegration.enableStats || cfg.mpdIntegration.enableUpdate) {
      programs.beets.settings.mpd = {
        host = cfg.mpdIntegration.host;
        port = cfg.mpdIntegration.port;
      };
    })
    (mkIf cfg.mpdIntegration.enableStats {
      programs.beets.settings.plugins = [ "mpdstats" ];
    })
    (mkIf cfg.mpdIntegration.enableUpdate {
      programs.beets.settings.plugins = [ "mpdupdate" ];
    })
    (mkIf (cfg.enable && cfg.mpdIntegration.enableStats) {
      systemd.user.services."beets-mpdstats" = {
        Unit = {
          Description = "Beets MPDStats daemon";
          After = optional config.services.mpd.enable "mpd.service";
          Requires = optional config.services.mpd.enable "mpd.service";
        };
        Service.ExecStart = "${cfg.package}/bin/beet mpdstats";
        Install.WantedBy = [ "default.target" ];
      };
    })
  ];
}

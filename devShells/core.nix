{ pkgs, recursiveMerge, agenix, ... }:
# { pkgs, runPkg, ... }:
  let 

    # runPkg = pkgs: pkg: "${pkgs.${pkg}}/bin/${pkg}";
    # run = pkg: runPkg pkgs pkg;
    mapVar = map(x: x.name);  
    
    tui = with pkgs; {
      packages = [ gum ];
      scripts = [ ];
      envvars = {
        nix = {
          USERNAME = "root";
          HOST = "localhost";
          PROVISION_METHOD = "eval ssh $USERNAME@$HOST";
          REMOTE_STORE = "eval ssh-ng://$USERNAME@$HOST";
        };
        gum = {
          GUM_CHOOSE_ORDERED = true;
          GUM_CHOOSE_ITEM_FOREGROUND = "";
          GUM_CHOOSE_SELECTED_FOREGROUND = "212";
          GUM_CHOOSE_HEADER_FOREGROUND = "240";
          # GUM_CONFIRM_TIMEOUT = "5s"; 
          # GUM_CONFIRM_DEFAULT = 
          # GUM_CONFIRM_PROMPT_FOREGROUND = 212;
          GUM_INPUT_PLACEHOLDER = "";
          # BORDER = "normal";
          # MARGIN = "1";
          # PADDING = "1 2";
          FOREGROUND = "212";
        };
      };
      hook = {
        shellHook = ''
          clear
          trap "clear" EXIT
          gum style --border="normal" --padding "1 2" --margin 1 --align="center" "Hello!
          Welcome to $(gum style --border="none" --padding 1 --background 140 $DESCRIPTION) environment."
          if [ "$TUI_DEPLOY" == "1" ];
            then
              gum confirm --negative="local" --affirmative="remote" --default=0 "Select provision method:"
              # PROVISION_METHOD=$(gum input --placeholder="ssh root@localhost")
              # PROVISION_METHOD=$(gum choose "$PROVISION_LOCAL" "$PROVISION_REMOTE" )
              if [[ -n $PROVISION_METHOD ]];
                then
                  USERNAME=$(gum input --prompt="username > " --placeholder="root" --value="root")
                  HOST=$(gum input --prompt="hostname > " --placeholder="localhost" --value="localhost")
              fi
          fi
          if [[ -n $TUI_HOOK ]];
            then
              gum style "Press C-c to enter shell!"
              EXEC_NEXT=$(gum choose $TUI_HOOK --select-if-one)
              if [ -z $EXEC_NEXT ];
                then
                  gum style "Nothing was picked or environment is not available. Welcome to shell!" 
                  TUI_EXIT="0"
                else 
                  gum confirm --negative="Nay" --affirmative="YOLO!" --default=0 $EXEC_NEXT && gum spin "$($EXEC_NEXT)" || gum style Abort!
                  gum style --foreground 260 Done! 
                  gum spin "sleep 3"
              fi
            else
              gum style "Environment is not available. Welcome to shell!"
          fi
          if [ "$TUI_EXIT" == "1" ];
            then
              exit
          fi
        '';
      };
        main = with tui; ({packages = packages ++ scripts;}  // envvars.gum // envvars.nix // hook);
    };


    core = with pkgs; {  
      packages = [
        git openssh rsync
        cmake dtc
      ];
      pyPackages = with python312Packages; [
        pip wheel setuptools
        west zephyr-python-api
      ];
      scripts = [
      (writeShellScriptBin "core-build" ''
        echo "meow
        sleep 5"
      '')
      (writeShellScriptBin "core-system-gc" ''
      	$PROVISION_METHOD nix-collect-garbage --delete-old
        $PROVISION_METHOD nix-store --optimize
        $PROVISION_METHOD nix store gc
      '')
      (writeShellScriptBin "core-doctor" ''
        $PROVISION_METHOD nix-store --verify --check-contents --repair
      '')
      ] ++ lib.optionals stdenv.isLinux [
      ] ++ lib.optionals stdenv.isDarwin [
      ];
      envvars = {
          DESCRIPTION = "Main shell";
          TUI_HOOK = mapVar core.scripts;
          TUI_DEPLOY = 1;
          TUI_EXIT = 1;
        }; 
      main = with core; ({packages = packages ++ pyPackages ++ scripts;} // envvars);
    };


    develop = with pkgs; {
      packages = [ 
        gnupg zip unzip
        helix niv nixpkgs-fmt nix-index
        superfile
        git git-crypt git-lfs git-remote-gcrypt gpg-tui
      ] ++ lib.optionals stdenv.isLinux [
        toybox
      ];
      scripts = [];
      envvars = {
       DESCRIPTION = "prototyping";
       TUI_HOOK = mapVar develop.scripts;
      };
      main = with develop; ({packages = packages ++ scripts;} // envvars);
    };


 in  {

    core = pkgs.mkShellNoCC
    ( recursiveMerge [ tui.main core.main ] );

    develop = pkgs.mkShell
    ( recursiveMerge [ tui.main develop.main ] );
 }


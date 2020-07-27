let
  myPythonOverride = {
    packageOverrides = self: super: rec {
      #fcsparser = super.callPackage ./fcsparser.nix {};
      #camel = super.callPackage ./camel.nix {};
      #cytoflow = super.callPackage ./cytoflow.nix {};
    };
  };
in
self: super: rec {

  # https://discourse.nixos.org/t/how-to-add-custom-python-package/536/4
  # python = super.python.override myPythonOverride;
  # python2 = super.python2.override myPythonOverride;
  python3 = super.python3.override myPythonOverride;
  python37 = super.python37.override myPythonOverride;
  python38 = super.python38.override myPythonOverride;

  #pythonPackages = python.pkgs;
  # python2Packages = python.pkgs;
  python3Packages = python3.pkgs;
  python37Packages = python37.pkgs;
  python38Packages = python38.pkgs;
}

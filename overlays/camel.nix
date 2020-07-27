{ buildPythonPackage, fetchPypi, pyyaml }:
buildPythonPackage rec {
  pname = "camel";
  version = "0.1.2";
  propagatedBuildInputs = [ pyyaml ];
  src = fetchPypi {
    inherit pname;
    inherit version;
    sha256sum = "f61080abbdd68ad40bfe4ecaee9ea34ff07344ad98d1f2041f0ccccbcf42f271";
  };
}

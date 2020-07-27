{ buildPythonPackage, fetchPypi, setuptools, six, numpy, pandas }:
buildPythonPackage rec {
  pname = "fcsparser";
  version = "0.2.1";
  propagatedBuildInputs = [ setuptools six numpy pandas ];
  src = fetchPypi {
    inherit pname;
    inherit version;
    sha256sum = "830c3f49df2e94a358bb45c5eed5c943c36529b223aab9c8e7a8870f2aba3c8d";
  };
}

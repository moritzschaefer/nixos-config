{ buildPythonPackage, fetchgit, swig, numpy, pandas, matplotlib, bottleneck, numexpr, scipy, scikitlearn, seaborn, statsmodels, nbformat, traits, traitsui, pyface, envisage, dateutil, yapf, pyopengl, qt4, pyqt4 }:
buildPythonPackage rec {
  pname = "cytoflow";
  version = "1.0";
  # name = "${pname}-${version}";
  nativeBuildInputs = [ swig ];
  propagatedBuildInputs = [ numpy pandas matplotlib bottleneck numexpr scipy scikitlearn seaborn statsmodels nbformat fcsparser traits traitsui pyface envisage dateutil yapf pyopengl qt4 pyqt4 ];
  # Relax version constraint
  patchPhase = ''
    sed -i 's/numpy==1.18.1/numpy/' setup.py
    sed -i 's/nbformat==5.0.4/nbformat/' setup.py
  '';
  doCheck = false;
  src = fetchgit {
    url = "https://github.com/bpteague/cytoflow";
    rev = "8515d4a0ef71940bf358ba86eb7d38b9d133d390";
    sha256 = "13zz5r9p2yivqqdk6jnacijkq4qwgjniljynjp88cxwq5mlw1ygv";
  };
}

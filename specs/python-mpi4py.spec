%global mpi4py_version 4.0.1
%global mpi_flavor %{?mpi_flavor}%{!?mpi_flavor:mpich}

Name:           python3-mpi4py-%{mpi_flavor}
Version:        %{mpi4py_version}
Release:        1
Summary:        Python bindings for MPI (%{mpi_flavor} variant)
License:        BSD-2-Clause
URL:            https://github.com/mpi4py/mpi4py
Source0:        mpi4py-%{version}.tar.gz

BuildRequires:  python3-devel
BuildRequires:  python3-setuptools
BuildRequires:  python3-Cython
BuildRequires:  %{mpi_flavor}-devel

Requires:       python3
Requires:       %{mpi_flavor}

%description
MPI for Python (mpi4py) provides bindings of the Message Passing Interface
(MPI) standard for the Python programming language. This package is built
against the %{mpi_flavor} MPI implementation.

%prep
%setup -q -n mpi4py-%{version}
# Fix Python 3.13 compat: distutils.log.warning() removed in setuptools 70+
sed -i 's/\.log\.warning\b/.log.warn/g' conf/mpiconfig.py conf/mpidistutils.py

%build
# Source the MPI environment
export PATH=%{_libdir}/%{mpi_flavor}/bin:$PATH
export LD_LIBRARY_PATH=%{_libdir}/%{mpi_flavor}:$LD_LIBRARY_PATH
export MPI_HOME=%{_libdir}/%{mpi_flavor}
# Override mpi.cfg hardcoded paths — tell mpi4py where our compilers live
export MPICC=%{_libdir}/%{mpi_flavor}/bin/mpicc
export MPICXX=%{_libdir}/%{mpi_flavor}/bin/mpicxx

python3 setup.py build

%install
export PATH=%{_libdir}/%{mpi_flavor}/bin:$PATH
export LD_LIBRARY_PATH=%{_libdir}/%{mpi_flavor}:$LD_LIBRARY_PATH
export MPI_HOME=%{_libdir}/%{mpi_flavor}
export MPICC=%{_libdir}/%{mpi_flavor}/bin/mpicc
export MPICXX=%{_libdir}/%{mpi_flavor}/bin/mpicxx

python3 setup.py install --skip-build --root=%{buildroot} --prefix=%{_prefix}

# Move to MPI-specific python path to avoid conflicts
mkdir -p %{buildroot}%{_libdir}/%{mpi_flavor}/python3/site-packages
mv %{buildroot}%{python3_sitearch}/mpi4py \
   %{buildroot}%{_libdir}/%{mpi_flavor}/python3/site-packages/
# Remove egg-info left in the original site-packages (not needed at runtime)
rm -rf %{buildroot}%{python3_sitearch}/mpi4py-*.egg-info

%files
%license LICENSE.rst
%{_libdir}/%{mpi_flavor}/python3/site-packages/mpi4py/

%changelog

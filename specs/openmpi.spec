%global openmpi_version 5.0.10

Name:           openmpi
Version:        %{openmpi_version}
Release:        1
Summary:        Open MPI — high-performance message passing library
License:        BSD-3-Clause
URL:            https://www.open-mpi.org
Source0:        openmpi-%{version}.tar.bz2

BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  gcc-fortran
BuildRequires:  python3
BuildRequires:  hwloc-devel
BuildRequires:  libnuma-devel
BuildRequires:  libevent-devel
BuildRequires:  libfabric-devel
BuildRequires:  pmix-devel
BuildRequires:  zlib-devel

Requires:       libfabric
Requires:       hwloc
Requires:       libevent

%description
Open MPI is a high-performance, production-quality implementation of MPI.
This build uses the OFI (libfabric) transport layer for Slingshot support.

%package devel
Summary:        Development files for Open MPI
Requires:       %{name} = %{version}-%{release}
Requires:       gcc-fortran

%description devel
Headers, modules, and compiler wrappers for building MPI applications
with Open MPI.

%prep
%setup -q -n openmpi-%{version}

%build
%configure \
  --prefix=%{_prefix} \
  --libdir=%{_libdir}/openmpi \
  --includedir=%{_includedir}/openmpi \
  --bindir=%{_libdir}/openmpi/bin \
  --mandir=%{_mandir}/openmpi \
  --with-ofi \
  --without-ucx \
  --with-pmix=internal \
  --with-hwloc=external \
  --with-libevent=external \
  --enable-shared \
  --disable-static \
  --enable-mpi-fortran=all \
  --disable-dependency-tracking \
  FFLAGS="-w" FCFLAGS="-w"

%make_build

%install
%make_install

# Remove libtool archives
find %{buildroot} -name '*.la' -delete

# Create modulefile
mkdir -p %{buildroot}%{_datadir}/modules/openmpi
cat > %{buildroot}%{_datadir}/modules/openmpi/%{version} <<EOF
#%%Module
proc ModulesHelp { } {
  puts stderr "Open MPI %{version} with OFI (libfabric)"
}
module-whatis "Open MPI %{version}"
prepend-path PATH %{_libdir}/openmpi/bin
prepend-path LD_LIBRARY_PATH %{_libdir}/openmpi
prepend-path MANPATH %{_mandir}/openmpi
setenv MPI_HOME %{_libdir}/openmpi
EOF

%files
%license LICENSE
%doc %{_datadir}/doc/openmpi/
%doc %{_datadir}/doc/pmix/
%doc %{_datadir}/doc/prrte/
%config(noreplace) %{_sysconfdir}/openmpi-mca-params.conf
%config(noreplace) %{_sysconfdir}/openmpi-totalview.tcl
%config(noreplace) %{_sysconfdir}/pmix-mca-params.conf
%config(noreplace) %{_sysconfdir}/prte-default-hostfile
%config(noreplace) %{_sysconfdir}/prte-mca-params.conf
%config(noreplace) %{_sysconfdir}/prte.conf
%dir %{_libdir}/openmpi
%dir %{_libdir}/openmpi/bin
%{_libdir}/openmpi/lib*.so.*
%{_libdir}/openmpi/bin/mpirun
%{_libdir}/openmpi/bin/mpiexec
%{_libdir}/openmpi/bin/ompi_info
%{_libdir}/openmpi/bin/opal_wrapper
%{_libdir}/openmpi/bin/oshrun
%{_libdir}/openmpi/bin/prte
%{_libdir}/openmpi/bin/prted
%{_libdir}/openmpi/bin/prte_info
%{_libdir}/openmpi/bin/prterun
%{_libdir}/openmpi/bin/prun
%{_libdir}/openmpi/bin/pterm
%{_libdir}/openmpi/bin/palloc
%{_libdir}/openmpi/bin/pattrs
%{_libdir}/openmpi/bin/pctrl
%{_libdir}/openmpi/bin/pevent
%{_libdir}/openmpi/bin/plookup
%{_libdir}/openmpi/bin/pmix_info
%{_libdir}/openmpi/bin/pps
%{_libdir}/openmpi/bin/pquery
%dir %{_libdir}/openmpi/openmpi/
%{_libdir}/openmpi/openmpi/*.so
%dir %{_libdir}/openmpi/pmix/
%{_libdir}/openmpi/pmix/*.so
%{_mandir}/openmpi/
%{_datadir}/modules/openmpi/
%{_datadir}/openmpi/
%{_datadir}/pmix/
%{_datadir}/prte/

%files devel
%{_includedir}/openmpi/
%{_libdir}/openmpi/lib*.so
%{_libdir}/openmpi/bin/mpicc
%{_libdir}/openmpi/bin/mpicxx
%{_libdir}/openmpi/bin/mpic++
%{_libdir}/openmpi/bin/mpiCC
%{_libdir}/openmpi/bin/mpif77
%{_libdir}/openmpi/bin/mpif90
%{_libdir}/openmpi/bin/mpifort
%{_libdir}/openmpi/bin/pmixcc
%{_libdir}/openmpi/pkgconfig/
%{_libdir}/openmpi/*.mod

%changelog

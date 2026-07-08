%global mercury_version 2.4.1

Name:           mercury
Version:        %{mercury_version}
Release:        1
Summary:        Mercury — RPC framework for HPC
License:        BSD-3-Clause
URL:            https://github.com/mercury-hpc/mercury
Source0:        mercury-%{version}.tar.gz

BuildRequires:  cmake >= 3.16
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  boost-devel
BuildRequires:  libfabric-devel
BuildRequires:  argobots-devel
BuildRequires:  pkg-config

Requires:       libfabric
Requires:       argobots

%description
Mercury is an RPC framework specifically designed for use in HPC systems.
It allows RDMA-capable network transports and is used by DAOS, Mochi, and
other HPC middleware.

%package devel
Summary:        Development files for Mercury
Requires:       %{name} = %{version}-%{release}
Requires:       argobots-devel
Requires:       libfabric-devel

%description devel
Development headers and libraries for building against Mercury.

%prep
%setup -q -n mercury-%{version}

%build
mkdir -p build && cd build
cmake \
  -DCMAKE_INSTALL_PREFIX=%{_prefix} \
  -DCMAKE_INSTALL_LIBDIR=%{_libdir} \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_TESTING=OFF \
  -DMERCURY_USE_BOOST_PP=ON \
  -DNA_USE_OFI=ON \
  -DNA_USE_SM=ON \
  -DMERCURY_USE_CHECKSUMS=ON \
  -DMERCURY_USE_SYSTEM_MCHECKSUM=OFF \
  -DMERCURY_USE_SYSTEM_BOOST=OFF \
  ..
%make_build

%install
cd build
%make_install

%files
%license LICENSE.txt
%{_prefix}/lib/lib*.so.*
%{_bindir}/hg_info

%files devel
%{_includedir}/*
%{_prefix}/lib/lib*.so
%{_datadir}/cmake/mercury/
%{_datadir}/cmake/mchecksum/
%{_prefix}/lib/pkgconfig/

%changelog

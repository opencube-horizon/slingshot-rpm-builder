%define isal_crypto_version %{?isal_crypto_ver}%{!?isal_crypto_ver:2.26.1}

Name:           libisal_crypto
Version:        %{isal_crypto_version}
Release:        1
Summary:        Intel Intelligent Storage Acceleration Library - Crypto
License:        BSD-3-Clause
URL:            https://github.com/intel/isa-l_crypto

Source0:        isa-l_crypto-%{version}.tar.gz

BuildRequires:  autoconf automake libtool
%ifarch x86_64
BuildRequires:  nasm >= 2.14
%endif

%description
ISA-L_crypto is a collection of optimized low-level cryptographic functions
targeting storage applications, including multi-buffer hashing (SHA, MD5)
and AES.

%package devel
Summary:        Development files for ISA-L_crypto
Requires:       %{name} = %{version}-%{release}

%description devel
Headers and libraries for developing applications using ISA-L_crypto.

%prep
%autosetup -n isa-l_crypto-%{version}

%build
./autogen.sh
%configure --prefix=%{_prefix} --libdir=%{_libdir}
%make_build

%install
%make_install
rm -f %{buildroot}%{_libdir}/*.la

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%files
%license LICENSE
%{_libdir}/libisal_crypto.so.*

%files devel
%{_includedir}/isa-l_crypto.h
%{_includedir}/isa-l_crypto/
%{_libdir}/libisal_crypto.so
%{_libdir}/libisal_crypto.a
%{_libdir}/pkgconfig/libisal_crypto.pc

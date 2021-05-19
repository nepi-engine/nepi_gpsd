#!/usr/bin/env bash
set -e
set -x



export PATH=/usr/sbin:/usr/bin:/sbin:/bin
if uname -a | grep -qi freebsd; then
    export PATH="${PATH}:/usr/local/bin:/usr/local/sbin"
fi

if [ "${USE_CCACHE}" = "true" ] && [ -n "${CCACHE_DIR}" ] && command -v ccache >/dev/null; then

    # create dir first, required by realpath
    mkdir -p "${CCACHE_DIR}"

    # fix for ccache: error: BASEDIR: not an absolute path
    export CCACHE_DIR=$(realpath "${CCACHE_DIR}")
    export CCACHE_BASEDIR=$(realpath "${CCACHE_BASEDIR}")

    if [ -d "/usr/lib64/ccache" ]; then
        # fedora
        export PATH="/usr/lib64/ccache:${PATH}"
    elif [ -d "/usr/local/libexec/ccache/" ]; then
        # freebsd
        export PATH="/usr/local/libexec/ccache:${PATH}"
    else
        # debian, .....
        export PATH="/usr/lib/ccache:${PATH}"
    fi
    echo 'max_size = 100M' > "${CCACHE_DIR}/ccache.conf"
else
    export USE_CCACHE="false"
fi

if command -v lsb_release >/dev/null && lsb_release -d | grep -qi -e debian -e ubuntu; then
    eval "$(dpkg-buildflags --export=sh)"
    export DEB_HOST_MULTIARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH)
    export PYTHONS="$(pyversions -v -r '>= 2.3'; py3versions -v -r '>= 3.4')"
    SCONSOPTS="${SCONSOPTS} libdir=/usr/lib/${DEB_HOST_MULTIARCH}"
else
    SCONSOPTS="${SCONSOPTS} libdir=/usr/lib"
fi

SCONSOPTS="${SCONSOPTS} $@ prefix=/usr"
SCONSOPTS="${SCONSOPTS} systemd=yes"
SCONSOPTS="${SCONSOPTS} nostrip=yes"
SCONSOPTS="${SCONSOPTS} dbus_export=yes"
SCONSOPTS="${SCONSOPTS} docdir=/usr/share/doc/gpsd"
SCONSOPTS="${SCONSOPTS} gpsd_user=gpsd"
SCONSOPTS="${SCONSOPTS} gpsd_group=dialout"
SCONSOPTS="${SCONSOPTS} debug=yes"
# set qt_versioned here only for non-CentOS systems (CentOS below)
if [ ! -f "/etc/centos-release" ]; then
    SCONSOPTS="${SCONSOPTS} qt_versioned=5"
fi

export SCONS=$(command -v scons)

if command -v nproc >/dev/null; then
    NPROC=$(nproc)
    SCONS_PARALLEL="-j ${NPROC} "
    if [ "${SLOW_CHECK}" != "yes" ]; then
        CHECK_NPROC=$(( 4 * ${NPROC} ))
        SCONS_CHECK_PARALLEL="-j ${CHECK_NPROC} "
    else
        SCONS_CHECK_PARALLEL="${SCONS_PARALLEL}"
    fi
else
    SCONS_PARALLEL=""
    SCONS_CHECK_PARALLEL=""
fi

if [ -f "/etc/centos-release" ]; then
    if grep -q "^CentOS Linux release 7" /etc/centos-release ; then
        export PYTHONS="2"
        # Qt version 5 currently doesn't compile, so omit versioning
        # for now
        #SCONSOPTS="${SCONSOPTS} qt_versioned=5"
    elif grep -q "^CentOS Linux release 8" /etc/centos-release ; then
        export SCONS=$(command -v scons-3)
        export PYTHONS="3"
        SCONSOPTS="${SCONSOPTS} qt_versioned=5"
    else
        # other CentOS versions not explicitly considered here, handle
        # as per non-CentOS logic
        SCONSOPTS="${SCONSOPTS} qt_versioned=5"
    fi
fi

export SCONSOPTS

if [ -z "$PYTHONS" ]; then
    export PYTHONS="3"
fi

if [ -n "${SCAN_BUILD}" ]; then
    export PYTHONS="3"
fi

for py in $PYTHONS; do
    _SCONS="${SCONS} target_python=python${py}"
    python${py}     ${_SCONS} ${SCONSOPTS} --clean
    rm -f .sconsign.*.dblite
    ${SCAN_BUILD} python${py}     ${_SCONS} ${SCONS_PARALLEL}${SCONSOPTS} build-all
    if [ -z "${NOCHECK}" ]; then
        python${py}     ${_SCONS} ${SCONS_CHECK_PARALLEL}${SCONSOPTS} check
    fi
done



if [ "${USE_CCACHE}" = "true" ]; then
    ccache -s
fi

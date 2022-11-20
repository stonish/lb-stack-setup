#!/bin/bash -e

# inspired from https://github.com/eclipse/che-dockerfiles/blob/master/recipes/stack-base/centos/entrypoint.sh

if [ -n "$TRACE_ENTRYPOINT" ] ; then
  set -x
fi

export USER_ID=$(id -u)
export GROUP_ID=$(id -g)

if [ ${USER_ID} == 0 ] ; then
  export USER=root
  export GROUP=root
  export HOME=/root
else
  export USER=${USER:-lhcb}
  export GROUP=${GROUP:-lhcb}
  export HOME=/userhome

  if ! grep -Fq "${GROUP_ID}" /etc/group ; then
    # group id is unknown we have to add it
    if [ "${GROUP}" != lhcb ] ; then
      groupadd -g ${GROUP_ID} ${GROUP}
    else
      groupmod -g ${GROUP_ID} lhcb
    fi
  fi
  if ! grep -q "^[^:]*:[^:]*:${USER_ID}:" /etc/passwd ; then
    # user id is unknown we have to add it
    if [ "${USER}" != lhcb ] ; then
      useradd -u ${USER_ID} -g ${GROUP} -M -d ${HOME} -G root,wheel,users ${USER}
    else
      usermod -u ${USER_ID} -g ${GROUP} -m -d ${HOME} -G root,wheel,users lhcb
    fi
  fi
fi

if [ -z "$NO_CVMFS" -a -e /opt/cctools/bin/parrot_run ] && ! /opt/cctools/bin/parrot_run --is-running > /dev/null ; then
  if [ ! -e /cvmfs/lhcb.cern.ch/lib ] ; then
    # no cvmfs, try using parrot
    # note: change directory to avoid parrot cvmfs module to pollute workspace
    workdir=$PWD
    cd /tmp
    # check if we can run anything in parrot
    /opt/cctools/bin/parrot_run ${PARROT_OPTIONS} -w $workdir true || (
      echo "ERROR: in-container mount of /cvmfs requires '--security-opt seccomp=unconfined' option to docker run" && \
        false)
    /opt/cctools/bin/parrot_run ${PARROT_OPTIONS} -w $workdir $0 "$@"
    exit
  fi
fi

if [ -n "$1" ] ; then
  set +xv
  . /etc/profile.d/lhcb.sh
  exec "$@"
else
  exec /bin/bash
fi


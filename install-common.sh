CONTRIB=${CONTRIB:-$(pwd)/contrib}
KEEP_SRC=${KEEP_SRC:-false}
PATH="/cvmfs/lhcb.cern.ch/lib/contrib/git/2.14.2/bin${PATH:+:${PATH}}"

setup() {
    local REPO="$1"
    local SHA="$2"
    local SRC="$CONTRIB/src/$(basename $REPO .git)"
    local OLD_DIR=$(pwd)
    local REMOVE=false
    
    if [ ! -d "$SRC" ] ; then
        # if the source directory does not exist, clone and remove it afterwards
        [ "$KEEP_SRC" = true ] || REMOVE=true
        mkdir -p "$SRC"
        
        cd "$SRC"
        # "shallow clone" working with a sha:
        git init
        git remote add origin "$REPO"
        git fetch --depth 1 origin "$SHA"
        git checkout FETCH_HEAD
        # shallow clone
        # git clone -b "$SHA" --single-branch --depth 1 "$REPO" "$SRC"
        # full clone with checkout
        # git clone "$REPO" "$SRC"
        # git checkout "$SHA"
    fi

    if [ "$REMOVE" = true ]; then
        eval "cleanup() { cd \"${OLD_DIR}\"; rm -rf \"${SRC}\"; }"
    else
        eval "cleanup() { cd \"${OLD_DIR}\"; }"
    fi

    cd "$SRC"
}
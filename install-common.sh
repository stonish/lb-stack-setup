CONTRIB=${CONTRIB:-$(pwd)/contrib}
KEEP_SRC=${KEEP_SRC:-false}
PATH="/cvmfs/lhcb.cern.ch/lib/contrib/git/2.14.2/bin${PATH:+:${PATH}}"

setup() {
    REPO="$1"
    SHA="$2"
    SRC="$CONTRIB/src/$(basename $REPO .git)"
    OLD_DIR=$(pwd)

    
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
    else
        REMOVE=false  # never remove $SRC if already existed
    fi

    if [ "$REMOVE" = true ]; then
        eval "cleanup() { cd \"${OLD_DIR}\"; rm -rf \"${SRC}\"; }"
    else
        eval "cleanup() { cd \"${OLD_DIR}\"; }"
    fi

    cd "$SRC"
}
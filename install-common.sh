CONTRIB=${CONTRIB:-$(pwd)/contrib}
KEEP_SRC=${KEEP_SRC:-false}
PATH="/cvmfs/lhcb.cern.ch/lib/contrib/git/2.14.2/bin${PATH:+:${PATH}}"

setup() {
    local REPO="$1"
    local SHA="$2"
    local SRC="$(mktemp --tmpdir -d lb-stack-setup-install.XXXXX)/$(basename $REPO .git)"
    local OLD_DIR=$(pwd)
    local REMOVE=false
    
    if [ ! -d "$SRC" ] ; then
        # if the source directory does not exist, clone and remove it afterwards
        [ "$KEEP_SRC" = true ] || REMOVE=true
        mkdir -p "$SRC"
        
        cd "$SRC"
        git init
        git remote add origin "$REPO"
        # try fetching only the commit, if remote does not allow, do full fetch
        if git fetch --depth 1 origin "$SHA" 2>/dev/null; then
            git checkout FETCH_HEAD
        else
            git fetch origin
            git checkout "$SHA"
        fi
    fi

    if [ "$REMOVE" = true ]; then
        eval "cleanup() { cd \"${OLD_DIR}\"; rm -rf \"${SRC}\"; }"
    else
        eval "cleanup() { cd \"${OLD_DIR}\"; }"
    fi

    cd "$SRC"
}

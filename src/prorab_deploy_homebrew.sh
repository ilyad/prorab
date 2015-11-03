#!/bin/sh

#Script for quick deployment to homebrew.
#It assumes that homebrew recipes to deploy are in 'homebrew' directory.


while true; do
    case $1 in
        --help)
            echo "Usage:"
            echo "\t$(basename $0) <tap-name>"
            echo " "
            echo "GitHub username and access token should be in GITHUB_USERNAME and GITHUB_ACCESS_TOKEN environment variable."
            echo " "
            echo "Example:"
            echo "\t$(basename $0) igagis/tap"
            exit 0
        ;;
        *)
            break
        ;;
    esac
done


#parse homebrew tap name
tap=(${1//\// })

username="${tap[0]}"
tapname="homebrew-${tap[1]}"

#update version numbers
make ver

#clean if needed
rm -rf $tapname

git config --global credential.helper store


#clone tap repo
repo=https://$GITHUB_USERNAME:$GITHUB_ACCESS_TOKEN@github.com/$username/$tapname.git
#echo "repo = $repo"
git clone $repo

recipes=$(ls homebrew/*.rb)

#echo "$recipes"

for f in $recipes
do
    url=$(awk '/\ *url\ *"http.*\.tar.gz"$/{print $2}' $f | sed -n -e 's/^"\(.*\)"$/\1/p')
#    echo "url = $url"
    filename=$(echo $url | sed -n -e 's/.*\/\([^\/]*\.tar\.gz\)$/\1/p')
#    echo "filename = $filename"
    curl -O $url
    sha=($(shasum -p -a 256 $filename))
    sha=${sha[0]}
#    echo "sha = $sha"
    sedcommand="s/\$(sha256)/$sha/"
#    echo "sedcommand = $sedcommand"
    sed $sedcommand $f > $f.out
    mv $f.out $f
    cp $f $tapname
    (cd $tapname; git commit -a -m"new formula version")
done

(cd $tapname; git status; git diff; git push)
#!/bin/bash

# Exit if a command fails
set -e

OWNER="$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f 1)"

if [[ "$INPUT_ADOC_FILE_EXT" != .* ]]; then
    INPUT_ADOC_FILE_EXT=".$INPUT_ADOC_FILE_EXT";
fi

echo "Configure git"
apk add openssh-client -q > /dev/null

git config --global --add safe.directory /github/workspace
git fetch --all

# Checkout to destination working branch
echo "Checking out the ${GITHUB_REF##*/} branch (keeping its history) from commit $GITHUB_SHA"
git checkout "$GITHUB_SHA" -B ${GITHUB_REF##*/}

# Executes any arbitrary shell command (such as packages installation and environment setup)
# before starting build.
# If no command is provided, the default value is just an echo command.
eval "$INPUT_PRE_BUILD"

echo "Converting AsciiDoc files to HTML and PDF"
eval find . $INPUT_FIND_PARAMS -name "*$INPUT_ADOC_FILE_EXT" -exec asciidoctor -b html $INPUT_ASCIIDOCTOR_PARAMS {} \\\;
eval find . $INPUT_FIND_PARAMS -name "*$INPUT_ADOC_FILE_EXT" -exec asciidoctor-pdf -b pdf -a icons=font -a icon-set=pf $INPUT_ASCIIDOCTOR_PARAMS {} \\\;
find . -name "README.html" -execdir ln -s "README.html" "index.html" \;

# Executes any post-processing command provided by the user, before changes are committed.
# If no command is provided, the default value is just an echo command.
echo "Running post build command."
eval "$INPUT_POST_BUILD"

echo "Adding output files to ${GITHUB_REF##*/} branch."
find . -name "*.pdf" -exec git add -f {} \;
find . -name "*.html" -exec git add -f {} \;

# Changes in gh-pages branch will be shown as the "GitHub Action" user.
git config --global user.email "action@github.com"
git config --global user.name "GitHub Action"

MSG="Convert $INPUT_ADOC_FILE_EXT Files into PDF/HTML from $GITHUB_SHA"
echo "Committing changes to gh-pages branch"
git commit -m "$MSG" 1>/dev/null

# If the action is being run into the GitHub Servers,
# the checkout action (which is being used)
# automatically authenticates the container using ssh.
# If the action is running locally, for instance using https://github.com/nektos/act,
# we need to push via https with a Personal Access Token
# which should be provided by an env variable.
# We ca run the action locally using act with:
#    act -s GITHUB_TOKEN=my_github_personal_access_token
if ! ssh -T git@github.com > /dev/null 2>/dev/null; then
    URL="https://$GITHUB_TOKEN@github.com/$GITHUB_REPOSITORY.git"
    git remote remove origin
    git remote add origin "$URL"
fi

echo "Pushing changes back to the remote repository"
git push -f --set-upstream origin ${GITHUB_REF##*/}
